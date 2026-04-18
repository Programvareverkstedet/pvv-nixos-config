{ fp, pkgs, values, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix

    (fp /base)
    #./services/nginx

    #./services/calendar-bot.nix
    #./services/git-mirrors
    #./services/minecraft-heatmap.nix
    #./services/mysql
    #./services/postgresql

    #./services/matrix
  ];

  boot.loader = {
    systemd-boot.enable = false; # no uefi support on this device
    grub.device = "/dev/disk/by-id/scsi-3600508b1001ca9cf1c96afea40d5451d";
    grub.enable = true;
  };

  boot = {
    zfs = {
      extraPools = [ "bicepdata" ];
      requestEncryptionCredentials = false;
    };
    supportedFilesystems.zfs = true;

    kernelPackages = pkgs.linuxPackages;
  };

  services.zfs.autoScrub = {
    enable = true;
    interval = "Wed *-*-8..14 00:00:00";
  };

  networking.hostId = "3b4bf6a5";
  systemd.network.networks."30-ens10f3" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens10f3";
    # IPs belong to guest1.pvv.ntnu.no
    address = [ "129.241.210.248/25" "2001:700:300:1900::248/63" ];
  };
  systemd.network.wait-online = {
    anyInterface = true;
  };

  # local overrides
  services.smartd.enable = lib.mkForce false;
  system.autoUpgrade.enable = lib.mkForce false;
  #services.userborn.enable = lib.mkForce false;
  #services.userdbd.enable = lib.mkForce false;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
