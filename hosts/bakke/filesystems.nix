{ config, pkgs, lib, ... }:
{
  # Boot drives:
  boot.swraid.enable = true;

  # ZFS Data pool:
  environment.systemPackages = with pkgs; [ zfs ];
  boot = {
    zfs = {
      extraPools = [ "tank" ];
      requestEncryptionCredentials = false;
    };
    supportedFilesystems = [ "zfs" ];
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  };
  services.zfs.autoScrub = {
    enable = true;
    interval = "Wed *-*-8..14 00:00:00";
  };

  # NFS Exports:
  #TODO

  # NFS Import mounts:
  #TODO
}
