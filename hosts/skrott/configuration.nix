{ config, pkgs, lib, fp, values, ... }: {
  imports = [
    # ./hardware-configuration.nix

    (fp /base)
  ];

  sops.defaultSopsFile = fp /secrets/skrott/skrott.yaml;

  boot = {
    consoleLogLevel = 0;
    enableContainers = false;
    loader.grub.enable = false;
    loader.systemd-boot.enable = false;
    kernelPackages = pkgs.linuxPackages;
  };

  # Now turn off a bunch of stuff lol
  system.autoUpgrade.enable = lib.mkForce false;
  services.irqbalance.enable = lib.mkForce false;
  services.logrotate.enable = lib.mkForce false;
  services.nginx.enable = lib.mkForce false;
  services.postfix.enable = lib.mkForce false;
  services.smartd.enable = lib.mkForce false;
  services.udisks2.enable = lib.mkForce false;
  services.thermald.enable = lib.mkForce false;
  services.promtail.enable = lib.mkForce false;
  boot.supportedFilesystems.zfs = lib.mkForce false;
  documentation.enable = lib.mkForce false;

  # TODO: can we reduce further?

  sops.secrets = {
    "dibbler/postgresql/password" = {
      owner = "dibbler";
      group = "dibbler";
    };
  };

  # zramSwap.enable = true;

  networking = {
    hostName = "skrot";
    defaultGateway = values.hosts.gateway;
    defaultGateway6 = values.hosts.gateway6;
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = values.hosts.skrott.ipv4;
        prefixLength = 25;
      }];
      ipv6.addresses = [{
        address = values.hosts.skrott.ipv6;
        prefixLength = 25;
      }];
    };
  };

  services.dibbler = {
    enable = true;
    kioskMode = true;
    limitScreenWidth = 80;
    limitScreenHeight = 42;

    settings = {
      general.quit_allowed = false;
      database = {
        type = "postgresql";
        postgresql = {
          username = "pvv_vv";
          dbname = "pvv_vv";
          host = "postgres.pvv.ntnu.no";
          password_file = config.sops.secrets."dibbler/postgresql/password".path;
        };
      };
    };
  };

  # https://github.com/NixOS/nixpkgs/issues/84105
  boot.kernelParams = [
    "console=ttyUSB0,9600"
    # "console=tty1" # Already part of the module
  ];
  systemd.services."serial-getty@ttyUSB0" = {
    enable = true;
    wantedBy = [ "getty.target" ]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
