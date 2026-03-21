{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.drumknotty;

  format = pkgs.formats.toml { };
in
{
  options.services.drumknotty = {
    enable = lib.mkEnableOption "DrumknoTTY";

    dibblerPackage = lib.mkPackageOption pkgs "dibbler" { };
    worblehatPackage = lib.mkPackageOption pkgs "worblehat" { };
    screenPackage = lib.mkPackageOption pkgs "screen" { };

    screenSessionName = lib.mkOption {
      type = lib.types.str;
      default = "drumknotty";
      example = "myscreensessionname";
      description = ''
        Sets the screen session name.
      '';
    };

    createLocalDatabase = lib.mkEnableOption "" // {
      description = ''
        Whether to set up a local postgres database automatically.

        ::: {.note}
        You must set up postgres manually before enabling this option.
        :::
      '';
    };

    kioskMode = lib.mkEnableOption "" // {
      description = ''
        Whether to let dibbler take over the entire machine.

        This will restrict the machine to a single TTY and make the program unquittable.
        You can still get access to PTYs via SSH and similar, if enabled.
      '';
    };

    limitScreenHeight = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      example = 42;
      description = ''
        If set, limits the height of the screen dibbler uses to the given number of lines.
      '';
    };

    limitScreenWidth = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      example = 80;
      description = ''
        If set, limits the width of the screen dibbler uses to the given number of columns.
      '';
    };

    dibblerSettings = lib.mkOption {
      description = "Configuration for dibbler";
      default = { };
      type = lib.types.submodule {
        freeformType = format.type;
      };
    };

    worblehatSettings = lib.mkOption {
      description = "Configuration for worblehat";
      default = { };
      type = lib.types.submodule {
        freeformType = format.type;
      };
    };

    deadline-daemon = {
      enable = lib.mkEnableOption "" // {
        description = ''
          Whether to enable the worblehat deadline-daemon service,
          which periodically checks for upcoming deadlines and notifies users.

          Note that this service is independent of the main worblehat service,
          and must be enabled separately.
        '';
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        description = ''
          How often to trigger rendering the map,
          in the format of a systemd timer onCalendar configuration.

          See {manpage}`systemd.timer(5)`.
        '';
        default = "*-*-* 10:15:00";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = [
          cfg.dibblerPackage
          cfg.worblehatPackage
        ];

        environment.etc."dibbler/dibbler.toml".source = format.generate "dibbler.toml" cfg.dibblerSettings;
        environment.etc."worblehat/config.toml".source =
          format.generate "worblehat-config.toml" cfg.worblehatSettings;

        users = {
          users.drumknotty = {
            group = "drumknotty";
            isNormalUser = true;
          };
          groups.drumknotty = { };
        };

        services.drumknotty.dibblerSettings = {
          limits = {
            low_credit_warning_limit = lib.mkDefault (-100);
            user_recent_transaction_limit = lib.mkDefault 100;
          };

          printer = {
            label_type = lib.mkDefault "62";
            label_rotate = lib.mkDefault false;
          };
        };

        services.drumknotty.worblehatSettings = {
          logging = {
            debug = lib.mkDefault true;
            debug_sql = lib.mkDefault false;
          };

          database = {
            type = lib.mkDefault "sqlite";
            sqlite.path = lib.mkDefault "./worblehat.sqlite";
            postgresql = {
              host = lib.mkDefault "localhost";
              port = lib.mkDefault 5432;
              username = lib.mkDefault "worblehat";
              password = lib.mkDefault "/var/lib/worblehat/db-password";
              database = lib.mkDefault "worblehat";
            };
          };

          flask = {
            TESTING = lib.mkDefault true;
            DEBUG = lib.mkDefault true;
            FLASK_ENV = lib.mkDefault "development";
            SECRET_KEY = lib.mkDefault "change-me";
          };

          smtp = {
            enabled = lib.mkDefault false;
            host = lib.mkDefault "smtp.pvv.ntnu.no";
            port = lib.mkDefault 587;
            username = lib.mkDefault "worblehat";
            password = lib.mkDefault "/var/lib/worblehat/smtp-password";
            from = lib.mkDefault "worblehat@pvv.ntnu.no";
            subject_prefix = lib.mkDefault "[Worblehat]";
          };

          deadline_daemon = {
            enabled = lib.mkDefault true;
            dryrun = lib.mkDefault false;
            warn_days_before_borrowing_deadline = lib.mkDefault [
              5
              1
            ];
            days_before_queue_position_expires = lib.mkDefault 14;
            warn_days_before_expiring_queue_position_deadline = lib.mkDefault [
              3
              1
            ];
          };
        };

        services.drumknotty.dibblerSettings.database = lib.mkIf cfg.createLocalDatabase {
          type = "postgresql";
          postgresql.host = "/run/postgresql";
        };

        services.postgresql = lib.mkIf cfg.createLocalDatabase {
          ensureDatabases = [
            "dibbler"
            "worblehat"
          ];
          ensureUsers = [
            {
              name = "drumknotty";
              ensureDBOwnership = true;
              ensureClauses.login = true;
            }
          ];
        };

        systemd.services.dibbler-setup-database = lib.mkIf cfg.createLocalDatabase {
          description = "Dibbler database setup";
          wantedBy = [ "default.target" ];
          after = [ "postgresql.service" ];
          unitConfig = {
            ConditionPathExists = "!/var/lib/dibbler/.db-setup-done";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe cfg.dibblerPackage} --config /etc/dibbler/dibbler.toml create-db";
            ExecStartPost = "${lib.getExe' pkgs.coreutils "touch"} /var/lib/dibbler/.db-setup-done";
            StateDirectory = "dibbler";

            User = "drumknotty";
            Group = "drumknotty";
          };
        };

        systemd.services.worblehat-setup-database = lib.mkIf cfg.createLocalDatabase {
          description = "Worblehat database setup";
          wantedBy = [ "default.target" ];
          after = [ "postgresql.service" ];
          unitConfig = {
            ConditionPathExists = "!/var/lib/worblehat/.db-setup-done";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe cfg.worblehatPackage} --config /etc/worblehat/config.toml create-db";
            ExecStartPost = "${lib.getExe' pkgs.coreutils "touch"} /var/lib/worblehat/.db-setup-done";
            StateDirectory = "worblehat";

            User = "drumknotty";
            Group = "drumknotty";
          };
        };

      }
      (lib.mkIf cfg.kioskMode {
        boot.kernelParams = [
          "console=tty1"
        ];

        users.users.drumknotty = {
          extraGroups = [ "lp" ];
          shell =
            (pkgs.writeShellScriptBin "login-shell" "${lib.getExe' cfg.screenPackage "screen"} -x ${cfg.screenSessionName} -p dibbler")
            // {
              shellPath = "/bin/login-shell";
            };
        };

        services.drumknotty.dibblerSettings.general = {
          quit_allowed = false;
          stop_allowed = false;
        };

        services.drumknotty.worblehatSettings.general = {
          quit_allowed = false;
          stop_allowed = false;
        };

        systemd.services.drumknotty-screen-session = {
          description = "Drumknotty Screen Session";
          wantedBy = [
            "default.target"
          ];
          after =
            if cfg.createLocalDatabase then
              [
                "postgresql.service"
                "dibbler-setup-database.service"
                "worblehat-setup-database.service"
              ]
            else
              [
                "network.target"
              ];
          serviceConfig =
            let
              dibblerArgs = lib.cli.toCommandLineShellGNU { } {
                config = "/etc/dibbler/dibbler.toml";
              };

              worblehatArgs = lib.cli.toCommandLineShellGNU { } {
                config = "/etc/worblehat/config.toml";
              };

            in
            {
              Type = "forking";
              RemainAfterExit = false;
              Restart = "always";
              RestartSec = "5s";
              SuccessExitStatus = 1;

              User = "drumknotty";
              Group = "drumknotty";

              ExecStartPre = "-${lib.getExe' cfg.screenPackage "screen"} -X -S ${cfg.screenSessionName} kill";
              ExecStart =
                let
                  screenArgs = lib.escapeShellArgs [
                    # -dm creates the screen in detached mode without accessing it
                    "-dm"

                    # Session name
                    "-S"
                    "${cfg.screenSessionName}"

                    # Window name
                    "-t"
                    "dibbler"

                    # Set optimal output mode instead of VT100 emulation
                    "-O"

                    # Enable login mode, updates utmp entries
                    "-l"
                  ];

                in
                "${lib.getExe' cfg.screenPackage "screen"} ${screenArgs} ${lib.getExe cfg.dibblerPackage} ${dibblerArgs} loop";
              ExecStartPost = [
                "${lib.getExe' cfg.screenPackage "screen"} -S ${cfg.screenSessionName} -X screen -t worblehat ${lib.getExe cfg.worblehatPackage} ${worblehatArgs} cli"
              ]
              ++ lib.optionals (cfg.limitScreenWidth != null) [
                "${lib.getExe' cfg.screenPackage "screen"} -X -S ${cfg.screenSessionName} width ${toString cfg.limitScreenWidth}"
              ]
              ++ lib.optionals (cfg.limitScreenHeight != null) [
                "${lib.getExe' cfg.screenPackage "screen"} -X -S ${cfg.screenSessionName} height ${toString cfg.limitScreenHeight}"
              ];
            };
        };

        services.getty.autologinUser = "drumknotty";
      })
      (lib.mkIf cfg.deadline-daemon.enable {
        systemd.timers.worblehat-deadline-daemon = {
          description = "Worblehat Deadline Daemon";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.deadline-daemon.onCalendar;
            Persistent = true;
          };
        };

        systemd.services.worblehat-deadline-daemon = {
          description = "Worblehat Deadline Daemon";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            CPUSchedulingPolicy = "idle";
            IOSchedulingClass = "idle";

            ExecStart =
              let
                worblehatArgs = lib.cli.toCommandLineShellGNU { } {
                  config = "/etc/worblehat/config.toml";
                };
              in
              "${lib.getExe cfg.package} ${worblehatArgs} deadline-daemon";

            User = "worblehat";
            Group = "worblehat";
          };
        };
      })

    ]
  );

}
