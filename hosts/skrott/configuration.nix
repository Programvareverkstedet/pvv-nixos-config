{ config, pkgs, lib, modulesPath, fp, values, ... }: {
  imports = [
    (modulesPath + "/profiles/perlless.nix")

    (fp /base)
  ];

  # Disable import of a bunch of tools we don't need from nixpkgs.
  disabledModules = [ "profiles/base.nix" ];

  sops.defaultSopsFile = fp /secrets/skrott/skrott.yaml;

  boot = {
    consoleLogLevel = 0;
    enableContainers = false;
    loader.grub.enable = false;
    loader.systemd-boot.enable = false;
    kernelPackages = pkgs.linuxPackages;
  };

  hardware = {
    enableAllHardware = lib.mkForce false;
    firmware = [ pkgs.raspberrypiWirelessFirmware ];
  };

  # Now turn off a bunch of stuff lol
  # TODO: can we reduce further?
  # See also https://nixcademy.com/posts/minimizing-nixos-images/
  system.autoUpgrade.enable = lib.mkForce false;
  services.irqbalance.enable = lib.mkForce false;
  services.logrotate.enable = lib.mkForce false;
  services.nginx.enable = lib.mkForce false;
  services.postfix.enable = lib.mkForce false;
  services.smartd.enable = lib.mkForce false;
  services.udisks2.enable = lib.mkForce false;
  services.thermald.enable = lib.mkForce false;
  services.promtail.enable = lib.mkForce false;
  # There aren't really that many firmware updates for rbpi3 anyway
  services.fwupd.enable = lib.mkForce false;

  documentation.enable = lib.mkForce false;

  environment.enableAllTerminfo = lib.mkForce false;

  programs.neovim.enable = lib.mkForce false;
  programs.zsh.enable = lib.mkForce false;
  programs.git.package = pkgs.gitMinimal;

  nix.registry = lib.mkForce { };
  nix.nixPath = lib.mkForce [ ];

  sops.secrets = {
    "dibbler/postgresql/password" = {
      owner = "dibbler";
      group = "dibbler";
    };
  };

  # zramSwap.enable = true;

  networking = {
    hostName = "skrott";
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
  boot.kernelParams = lib.mkIf (!config.virtualisation.isVmVariant) [
    "console=ttyUSB0,9600"
    # "console=tty1" # Already part of the module
  ];
  systemd.services."serial-getty@ttyUSB0" = lib.mkIf (!config.virtualisation.isVmVariant) {
    enable = true;
    wantedBy = [ "getty.target" ]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
