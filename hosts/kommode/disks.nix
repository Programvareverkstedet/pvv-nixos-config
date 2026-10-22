{ lib, ... }:
{
  disko.devices = {
    disk = {
      boot = {
        type = "disk";
        device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP";
              label = "ESP";
              size = "100%";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
          };
        };
      };

      root = {
        type = "disk";
        device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
        content = {
          type = "gpt";
          partitions = {
            root = {
              name = "root";
              label = "root";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                subvolumes = let
                  makeSnapshottable = subvolPath: mountOptions: let
                    name = lib.replaceString "/" "_" subvolPath;
                  in {
                    "@rootfs${name}/active" = {
                      mountpoint = subvolPath;
                      inherit mountOptions;
                    };
                    "@rootfs${name}/snapshots" = {
                      mountpoint = "${subvolPath}/.snapshots";
                      inherit mountOptions;
                    };
                  };
                in { }
                // (makeSnapshottable "/var/lib/gitea" [ "compress=zstd:15" "space_cache=v2" "noatime" ])
                // (makeSnapshottable "/var/lib/gitea-web" [ "compress=zstd:15" "space_cache=v2" "noatime" ]);

                # swap.swapfile.size = "4G";
                mountpoint = "/";
                mountOptions = [ "relatime" "space_cache=v2" ];
              };
            };
          };
        };
      };
    };
  };
}
