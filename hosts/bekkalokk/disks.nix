{ lib, config, ... }:
let
  cfg = config.disko.devices.disk;
  mkDisk =
    {
      device,
      uuids,
      rootContent ? null,
      espMountpoint ? null,
    }:
    {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 3;
            size = "487M";
            type = "EF00";
            uuid = uuids.ESP;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = espMountpoint;
            };
          };

          root = {
            priority = 1;
            start = "488M";
            end = "-7629M";
            uuid = uuids.root;
            content = rootContent;
          };

          swap = {
            priority = 2;
            size = "100%";
            type = "8200";
            uuid = uuids.swap;
            content.type = "swap";
          };
        };
      };
    };
in
{
  disko.devices.disk = {
    disk1 = mkDisk {
      device = "/dev/disk/by-id/wwn-0x5000cca20eda2a59"; # sda
      uuids = {
        root = "12d5c21f-3f02-4db4-b6bb-1ee2a71766af";
        swap = "1e696263-7509-488d-a44c-069ea280d76d";
        ESP = "2f5ca726-9259-4acd-aafb-cce0d942a699";
      };
    };

    disk2 = mkDisk {
      device = "/dev/disk/by-id/wwn-0x5000cca20eda4863"; # sdb
      uuids = {
        root = "324505ad-fee0-43b3-965f-6025dfc687db";
        swap = "0ade9800-0dfd-45e4-be2d-c48dac45f918";
        ESP = "06a707eb-81f5-4c4e-8bf9-d2724dc7b835";
      };
    };

    disk3 = mkDisk {
      device = "/dev/disk/by-id/wwn-0x5000cca20eda47cc"; # sdc
      uuids = {
        root = "2570a8c8-7d08-44a9-a3e2-242c302e0ef9";
        swap = "36c2e973-0460-40fa-8e11-8f880ebf78ba";
        ESP = "d931abf2-22f1-42f2-bac6-3b46923889de";
      };
      espMountpoint = "/boot";
      rootContent = {
        type = "btrfs";
        extraArgs = [
          "-d raid1"
          "-m raid1"
          "-L bpool"
          cfg.disk1.content.partitions.root.device
          cfg.disk2.content.partitions.root.device
        ];

        subvolumes =
          let
            commonMountOptions = [ "space_cache=v2" ];

            subvolume' = name: mountpoint: mountOptions: let
              opts = commonMountOptions ++ mountOptions;
            in {
              "${name}/active" = {
                inherit mountpoint;
                mountOptions = opts;
              };
              "${name}/snapshots" = {
                mountpoint = "${lib.removeSuffix "/" mountpoint}/.snapshots";
                mountOptions = opts ++ [ "ro" "x-systemd.automount" "x-systemd.idle-timeout=5min" ];
              };
            };

            subvolume = mountpoint: subvolume' "@rootfs_${lib.replaceString "/" "_" (lib.removePrefix "/" mountpoint)}" mountpoint;
          in
          lib.foldl (x: y: x // y) { } [
            (subvolume' "@rootfs" "/" [ "compress=zstd" "noatime" ])

            (subvolume "/nix" [ "compress=zstd" "noatime" "nodev" ])
            (subvolume "/home" [ "compress=zstd" "noatime" "nodev" ])
            (subvolume "/root" [ "compress=zstd" "noatime" "nodev" ])

            (subvolume "/var" [ "compress=zstd" "noatime" ])
            (subvolume "/var/cache" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])
            (subvolume "/var/log" [ "compress=zstd" "noatime" "noexec" "nosuid" "nodev" ])
            (subvolume "/var/lib" [ "compress=zstd" "noatime" "nosuid" "nodev" ])
          ];
      };
    };
  };
}
