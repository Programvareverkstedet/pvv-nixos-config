{ lib, device }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              label = "ESP";
              start = "1M";
              end = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              name = "root";
              label = "root";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes =
                  let
                    commonMountOptions = [
                      "space_cache=v2"
                      "ssd"
                    ];

                    subvolume =
                      mountpoint: mountOptions:
                      let
                        name = lib.replaceString "/" "_" (lib.removePrefix "/" mountpoint);
                        opts = commonMountOptions ++ mountOptions;
                      in
                      {
                        "@rootfs_${name}/active" = {
                          inherit mountpoint;
                          mountOptions = opts;
                        };
                        "@rootfs_${name}/snapshots" = {
                          mountpoint = "${mountpoint}/.snapshots";
                          mountOptions = opts ++ [
                            "ro"
                            "x-systemd.automount"
                            "x-systemd.idle-timeout=5min"
                          ];
                        };
                      };
                  in
                  lib.foldl (x: y: x // y) { } [
                    {
                      "@" = { };
                      "@rootfs/active" = {
                        mountpoint = "/";
                        mountOptions = commonMountOptions ++ [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "@rootfs/snapshots" = {
                        mountpoint = "/.snapshots";
                        mountOptions = commonMountOptions ++ [
                          "compress=zstd"
                          "noatime"
                          "ro"
                          "x-systemd.automount"
                          "x-systemd.idle-timeout=5min"
                        ];
                      };
                    }

                    {
                      "/swap" = {
                        mountpoint = "/.swapvol";
                        swap = {
                          swapfile.size = "32G";
                        };
                      };
                    }

                    (subvolume "/nix" [
                      "compress=zstd"
                      "noatime"
                      "nodev"
                    ])
                    (subvolume "/home" [
                      "compress=zstd"
                      "noatime"
                      "nodev"
                    ])
                    (subvolume "/root" [
                      "compress=zstd"
                      "noatime"
                      "nodev"
                    ])
                    (subvolume "/var" [
                      "compress=zstd"
                      "noatime"
                    ])
                    (subvolume "/var/cache" [
                      "compress=zstd"
                      "noatime"
                      "noexec"
                      "nosuid"
                      "nodev"
                    ])
                    (subvolume "/var/log" [
                      "compress=zstd"
                      "noatime"
                      "noexec"
                      "nosuid"
                      "nodev"
                    ])
                    (subvolume "/var/lib" [
                      "compress=zstd"
                      "noatime"
                      "nosuid"
                      "nodev"
                    ])
                    (subvolume "/var/lib/containers/storage" [
                      "compress=zstd"
                      "noatime"
                    ])
                    (subvolume "/var/lib/containers/storage/volumes" [
                      "compress=zstd"
                      "noatime"
                    ])
                  ];
              };
            };
          };
        };
      };
    };
  };
}
