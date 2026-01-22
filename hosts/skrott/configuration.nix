{ config, pkgs, lib, fp, ... }: {
  imports = [
    # ./hardware-configuration.nix

    (fp /base)
  ];

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

  # TODO: can we reduce further?

  sops.secrets = {
    "dibbler/postgresql/url" = {
      owner = "dibbler";
      group = "dibbler";
    };
  };

  # zramSwap.enable = true;

  networking = {
    hostName = "skrot";
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "129.241.210.235";
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
      database.url = config.sops.secrets."dibbler/postgresql/url".path;
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
  system.stateVersion = "25.05";
}
