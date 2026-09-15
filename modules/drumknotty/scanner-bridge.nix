{
  config,
  pkgs,
  lib,
  ...
}:
let
  mainCfg = config.services.drumknotty;
  cfg = config.services.drumknotty.scannerBridge;

  script = pkgs.writers.writePython3Bin "drumknotty-scanner-bridge" {
    libraries = [ pkgs.python3Packages.evdev ];
  } (builtins.readFile ./scanner-bridge.py);
in
{
  options.services.drumknotty.scannerBridge = {
    enable = lib.mkEnableOption "forwarding input from a USB barcode/RFID scanner straight into a specific screen session";

    device = lib.mkOption {
      type = lib.types.path;
      example = "/dev/input/by-id/usb-Some_Vendor_Some_Scanner-event-kbd";
    };

    idVendor = lib.mkOption {
      type = lib.types.str;
      example = "ffff";
      description = "USB idVendor of the scanner";
    };

    idProduct = lib.mkOption {
      type = lib.types.str;
      example = "0035";
      description = "USB idProduct of the scanner";
    };

    targetDisplay = lib.mkOption {
      type = lib.types.str;
      default = "ttyUSB0";
      example = "tty1";
      description = ''
        Name of the screen display used in the screen session".
      '';
    };
  };

  config = lib.mkIf (mainCfg.enable && cfg.enable) {
    users.users.drumknotty.extraGroups = [ "input" ];

    services.drumknotty.screen.extraConfig = [
      "msgwait 0"
      "msgminwait 0"
    ];

    services.udev.extraRules = ''
      SUBSYSTEM=="input", ATTRS{idVendor}=="${cfg.idVendor}", ATTRS{idProduct}=="${cfg.idProduct}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="drumknotty-scanner-bridge.service"
    '';

    systemd.services.drumknotty-scanner-bridge = {
      description = "DrumknoTTY barcode scanner bridge";

      unitConfig.AssertPathExists = cfg.device;
      serviceConfig = {
        Type = "notify-reload";
        NotifyAccess = "main";
        Restart = "always";
        RestartSec = "1s";

        User = "drumknotty";
        Group = "drumknotty";

        ExecStart = let
          args = lib.cli.toCommandLineShellGNU { } {
            device = cfg.device;
            screen-bin = lib.getExe' mainCfg.screen.package "screen";
            session = mainCfg.screen.sessionName;
            target = cfg.targetDisplay;
          };
        in
          "${lib.getExe script} ${args}";

        PrivateNetwork = true;
        PrivateTmp = true;
      };
    };
  };
}
