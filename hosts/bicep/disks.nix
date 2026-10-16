{ lib, config, ... }:
let
  cfg = config.disko.devices.disk;
in
{
  disko.devices = {
    disk = {
      disk1 = {
        type = "disk";
        device = "/dev/disk/by-id/wwn-0x5002538f42553576"; # sda
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
        device = "/dev/disk/by-id/wwn-0x5002538f42553cd8"; # sdb
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
                  (subvolume "/var/cache" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])
                  (subvolume "/var/log" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])

                  (subvolume "/var/lib" [ "compress=zstd" "noatime" "nosuid" "nodev" ])

                  # NOTE: btrfs ignores nodatacow/compress per subvolume, only the first mount's options apply.
                  #       see the +C options below, as a workaround.
                  (subvolume "/var/lib/postgresql" [ "nodatacow" "noatime" "noexec" "nosuid" "nodev" ])
                  (subvolume "/var/lib/mysql" [ "nodatacow" "noatime" "noexec" "nosuid" "nodev"  ])

                  (subvolume "/var/lib/matrix-synapse" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])
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

  systemd.tmpfiles.settings."10-btrfs-nocow" = {
    "/var/lib/postgresql".h.argument = "+C";
    "/var/lib/mysql".h.argument = "+C";
  };
}
