{ pkgs, ... }:
{
  # Boot drives:
  boot.swraid.enable = true;

  # ZFS Data pool:
  boot = {
    zfs = {
      extraPools = [ "tank" ];
      requestEncryptionCredentials = false;
    };
    supportedFilesystems.zfs = true;
    # Use stable linux packages, these work with zfs
    kernelPackages = pkgs.linuxPackages;
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
