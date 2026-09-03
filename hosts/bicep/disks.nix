{ lib, config, ... }:
let
  cfg = config.disko.devices.disk;
in
{
  disko.devices = {
    disk = {
      disk1 = {
        type = "disk";
        device = "/dev/disk/by-id/wwn-0x600508b1001c6048d0ebfc1add4777cc"; # sda
        content = {
          type = "gpt";
          partitions = {
            bios = {
              size = "1M";
              type = "EF02";
            };

            root = {
              size = "100%";
            };
          };
        };
      };

      disk2 = {
        type = "disk";
        device = "/dev/disk/by-id/wwn-0x600508b1001ce4431e3cce19f0f6c96c"; # sdb
        content = {
          type = "gpt";
          partitions = {
            bios = {
              size = "1M";
              type = "EF02";
            };

            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-d raid1"
                  "-m raid1"
                  "-L nixos"
                  cfg.disk1.content.partitions.root.device
                ];

                subvolumes = let
                  commonMountOptions = [ "space_cache=v2" "ssd" ];

                  subvolume = mountpoint: mountOptions: let
                    name = lib.replaceString "/" "_" (lib.removePrefix "/" mountpoint);
                    opts = commonMountOptions ++ mountOptions;
                  in {
                    "@rootfs_${name}/active" = {
                      inherit mountpoint;
                      mountOptions = opts;
                    };
                    "@rootfs_${name}/snapshots" = {
                      mountpoint = "${mountpoint}/.snapshots";
                      mountOptions = opts ++ [ "ro" "x-systemd.automount" "x-systemd.idle-timeout=5min" ];
                    };
                  };
                in lib.foldl (x: y: x // y) { } [
                  {
                    "@" = { };
                    "@rootfs/active" = {
                      mountpoint = "/";
                      mountOptions = commonMountOptions ++ [ "compress=zstd" "noatime" ];
                    };
                    "@rootfs/snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = commonMountOptions ++ [ "compress=zstd" "noatime" "ro" "x-systemd.automount" "x-systemd.idle-timeout=5min" ];
                    };
                  }

                  (subvolume "/boot" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])
                  (subvolume "/nix" [ "compress=zstd" "noatime" "nodev" ])
                  (subvolume "/home" [ "compress=zstd" "noatime" "nodev" ])
                  (subvolume "/root" [ "compress=zstd" "noatime" "nodev" ])

                  (subvolume "/var" [ "compress=zstd" "noatime" ])
                  (subvolume "/var/cache" [ "compress=zstd" "noatime" ])
                  (subvolume "/var/log" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])

                  (subvolume "/var/lib" [ "compress=zstd" "noatime" "nosuid" "nodev" ])
                  (subvolume "/var/lib/postgresql" [ "nodatacow" "noatime" ])
                  (subvolume "/var/lib/mysql" [ "nodatacow" "noatime" ])
                  (subvolume "/var/lib/matrix-synapse" [ "compress=zstd" "noatime" ])
                  (subvolume "/var/lib/redis" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])

                  (subvolume "/var/lib/containers/storage" [ "compress=zstd" "noatime" ])
                  (subvolume "/var/lib/containers/storage/volumes" [ "compress=zstd" "noatime" ])
                ];
              };
            };
          };
        };
      };
    };
  };
}
