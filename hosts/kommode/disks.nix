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
                # subvolumes = let
                #   makeSnapshottable = subvolPath: mountOptions: let
                #     name = lib.replaceString "/" "-" subvolPath;
                #   in {
                #     "@${name}/active" = {
                #       mountPoint = subvolPath;
                #       inherit mountOptions;
                #     };
                #     "@${name}/snapshots" = {
                #       mountPoint = "${subvolPath}/.snapshots";
                #       inherit mountOptions;
                #     };
                #   };
                # in {
                #   "@" = { };
                #   "@/swap" = {
                #     mountpoint = "/.swapvol";
                #     swap.swapfile.size = "4G";
                #   };
                #   "@/root" = {
                #     mountpoint = "/";
                #     mountOptions = [ "compress=zstd" "noatime" ];
                #   };
                # }
                # // (makeSnapshottable "/home" [ "compress=zstd" "noatime" ])
                # // (makeSnapshottable "/nix" [ "compress=zstd" "noatime" ])
                # // (makeSnapshottable "/var/lib" [ "compress=zstd" "noatime" ])
                # // (makeSnapshottable "/var/log" [ "compress=zstd" "noatime" ])
                # // (makeSnapshottable "/var/cache" [ "compress=zstd" "noatime" ]);

                # swap.swapfile.size = "4G";
                mountpoint = "/";
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
