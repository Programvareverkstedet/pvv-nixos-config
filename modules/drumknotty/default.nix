{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.drumknotty;
in
{
  imports = [
    ./dibbler.nix
    ./worblehat.nix
  ];

  options.services.drumknotty = {
    enable = lib.mkEnableOption "DrumknoTTY";

    kioskMode = lib.mkEnableOption "" // {
      description = ''
        Whether to let dibbler take over the entire machine.

        This will restrict the machine to a single TTY and make the program unquittable.
        You can still get access to PTYs via SSH and similar, if enabled.
      '';
    };

    screen = {
      package = lib.mkPackageOption pkgs "screen" { };

      sessionName = lib.mkOption {
        type = lib.types.str;
        default = "drumknotty";
        example = "myscreensessionname";
        description = ''
          Sets the screen session name.
        '';
      };

      limitHeight = lib.mkOption {
        type = with lib.types; nullOr ints.unsigned;
        default = null;
        example = 42;
        description = ''
          If set, limits the height of the screen dibbler uses to the given number of lines.
        '';
      };

      limitWidth = lib.mkOption {
        type = with lib.types; nullOr ints.unsigned;
        default = null;
        example = 80;
        description = ''
          If set, limits the width of the screen dibbler uses to the given number of columns.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enable -> lib.any (b: b) [
          cfg.dibbler.enable
          cfg.worblehat.enable
        ];
        message = "DrumknoTTY must have at least one service enabled";
      }
    ];

    users = {
      users.drumknotty = {
        group = "drumknotty";
        extraGroups = [ "lp" ];
        isNormalUser = true;

        # TODO: make this display the error log or error message in case that
        #       the screen session service is bootlooping or otherwise off.
        shell =
          lib.mkIf cfg.kioskMode
          (pkgs.writeShellScriptBin "login-shell"
            "${lib.getExe' cfg.screen.package "screen"} -x ${cfg.screen.sessionName} -p dibbler"
          // {
            shellPath = "/bin/login-shell";
          });
      };
      groups.drumknotty = { };
    };

    boot.kernelParams = lib.mkIf cfg.kioskMode [
      "console=tty1"
    ];

    services.getty.autologinUser = lib.mkIf cfg.kioskMode "drumknotty";

    systemd.services.drumknotty-screen-session = lib.mkIf cfg.kioskMode {
      description = "Drumknotty Screen Session";
      wantedBy = [
        "default.target"
      ];
      after =
        # TODO: this could be refined
        if (cfg.dibbler.createLocalDatabase || cfg.worblehat.createLocalDatabase) then
          [
            "postgresql.service"
            "dibbler-setup-database.service"
            "worblehat-setup-database.service"
          ]
        else
          [
            "network.target"
          ];

      serviceConfig = {
        Type = "forking";
        RemainAfterExit = false;
        Restart = "always";
        RestartSec = "5s";
        SuccessExitStatus = 1;

        User = "drumknotty";
        Group = "drumknotty";

        ExecStartPre =
          let
            screenArgs = lib.escapeShellArgs [
              # Send the specified command to a running screen session
              "-X"

              # Session name
              "-S"
              "${cfg.screen.sessionName}"

              "kill"
            ];
          in
          "-${lib.getExe' cfg.screen.package "screen"} ${screenArgs}";

        ExecStart =
          let
            screenrc = let
              convertToFile = lines: lib.pipe lines [
                lib.concatLists
                (lib.concatStringsSep "\n")
                (pkgs.writeText "drumknotty-screenrc")
              ];
            in convertToFile [
              (lib.optionals (cfg.screen.limitWidth != null) [
                "screen width ${toString cfg.screen.limitWidth}"
              ])
              (lib.optionals (cfg.screen.limitHeight != null) [
                "screen height ${toString cfg.screen.limitHeight}"
              ])

              (let
                dibblerArgs = lib.cli.toCommandLineShellGNU { } {
                  config = "/etc/dibbler/dibbler.toml";
                };
              in lib.optionals cfg.dibbler.enable [
                "screen -t dibbler ${lib.getExe cfg.dibbler.package} ${dibblerArgs} loop"

              ])

              (let
                worblehatArgs = lib.cli.toCommandLineShellGNU { } {
                  config = "/etc/worblehat/config.toml";
                };
              in lib.optionals cfg.worblehat.enable [
                "screen -t worblehat ${lib.getExe cfg.worblehat.package} ${worblehatArgs} cli"
              ])

              [ "select 0" ]
            ];

            screenArgs = lib.escapeShellArgs [
              # -dm creates the screen in detached mode without accessing it
              "-dm"

              # Session name
              "-S"
              "${cfg.screen.sessionName}"

              # Set optimal output mode instead of VT100 emulation
              "-O"

              # Enable login mode, updates utmp entries
              "-l"

              # Config file path
              "-c"
              "${screenrc}"
            ];
          in
            "${lib.getExe' cfg.screen.package "screen"} ${screenArgs}";
      };
    };
  };
}
