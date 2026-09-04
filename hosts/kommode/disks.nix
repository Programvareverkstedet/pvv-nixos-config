{ lib, ... }:
{
  disko.devices = {
    disk = {
      sda = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            root = {
              name = "root";
              label = "root";
              start = "1MiB";
              end = "-5G";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                subvolumes = let
                  makeSnapshottable = subvolPath: mountOptions: let
                    name = lib.replaceString "/" "_" subvolPath;
                  in {
                    "@rootfs_${name}/active" = {
                      mountpoint = subvolPath;
                      inherit mountOptions;
                    };
                    "@rootfs_${name}/snapshots" = {
                      mountpoint = "${subvolPath}/.snapshots";
                      inherit mountOptions;
                    };
                  };
                in { }
                // (makeSnapshottable "/var/lib/gitea" [ "compress=zstd" "noatime" ])
                // (makeSnapshottable "/var/lib/gitea-web" [ "compress=zstd" "noatime" ]);

                # swap.swapfile.size = "4G";
                mountpoint = "/";
                mountOptions = [ "relatime" ];
              };
            };

            swap = {
              name = "swap";
              label = "swap";
              start = "-5G";
              end = "-1G";
              content.type = "swap";
            };

            ESP = {
              name = "ESP";
              label = "ESP";
              start = "-1G";
              end = "100%";
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
    };
  };
}
