{ fp, values, lib, lupineName, ... }:
{
  imports = [
    ./hardware-configuration/${lupineName}.nix

    (fp /base)
    ./services/gitea-runner.nix
  ] ++ lib.optionals (lupineName == "lupine-5") [
    ./services/openvpn.nix
  ] ++ lib.optionals (lupineName == "lupine-4") [
    (import ./disks.nix { inherit lib; device = "/dev/disk/by-id/ata-KINGSTON_SA400S37480G_50026B749D1448C1"; })
  ] ++ lib.optionals (lupineName == "lupine-3") [
    (import ./disks.nix { inherit lib; device = "/dev/disk/by-id/ata-SK_hynix_SC300_M.2_2280_256GB_FI62N00731070261Q"; })
  ] ++ lib.optionals (lupineName == "lupine-2") [
    (import ./disks.nix { inherit lib; device = "/dev/disk/by-id/ata-SanDisk_X400_M.2_2280_128GB_163735424394"; })
  ] ++ lib.optionals (lupineName == "lupine-1") [
    (import ./disks.nix { inherit lib; device = "/dev/disk/by-id/ata-LITEON_CV3-8D128-11_SATA_128GB_TW0WVD60LOH006BP0NTY"; })
  ];

  services.prometheus.exporters.node.disabledCollectors = lib.mkIf (lib.elem lupineName [ "lupine-1" "lupine-2" ]) [
    "thermal_zone"
  ];

  sops.defaultSopsFile = fp /secrets/lupine/lupine.yaml;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "i686-linux"
  ];

  systemd.network = lib.mkMerge [
    {
      # Podman/netavark manage these. networkd/resolved complain unless we leave them alone.
      networks."05-podman-unmanaged" = {
        matchConfig.Name = "podman*";
        linkConfig.Unmanaged = true;
      };
      networks."05-veth-unmanaged" = {
        matchConfig.Name = "veth*";
        linkConfig.Unmanaged = true;
      };
    }

    (if (lupineName != "lupine-5")
    then {
      networks."30-enp0s31f6" =  (values.defaultNetworkConfig // {
        matchConfig.Name = "enp0s31f6";
        address = with values.hosts.${lupineName}; [ (ipv4 + "/25") (ipv6 + "/64") ];
        networkConfig.LLDP = false;
      });

      wait-online = {
        anyInterface = true;
      };
    }
    else {
      netdevs."10-br0".netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };

      netdevs."20-tap0".netdevConfig = {
        Name = "tap0";
        Kind = "tap";
      };

      networks."10-enp0s31f6" = {
        matchConfig.Name = "enp0s31f6";
        bridge = [ "br0" ];
      };

      networks."20-br0" = {
        matchConfig.Name = "br0";

        address = with values.hosts.${lupineName}; [
          (ipv4 + "/25")
          (ipv6 + "/64")
          values.services.knutsen-vpn
        ];
        networkConfig.LLDP = false;

        inherit (values.defaultNetworkConfig) dns domains;
        gateway = [values.hosts.gateway values.hosts.gateway6];

        networkConfig.IPv6AcceptRA = "no";
        DHCP = "no";
      };

      networks."30-tap0" = {
        matchConfig.Name = "tap0";
        bridge = [ "br0" ];
      };

      links."30-tap0" = {
        matchConfig.OriginalName = "tap0";
        linkConfig.TransmitQueueLength = 1000;
      };

      wait-online = {
        anyInterface = true;
      };
    })
  ];

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.05";
}
