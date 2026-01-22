{ config, fp, pkgs, lib, values, ... }:

{
  imports = [
    (fp /base)

    ./services/gitea-runners.nix
  ];

  boot.loader.systemd-boot.enable = false;

  networking.useHostResolvConf = lib.mkForce false;

  systemd.network.networks = {
    "30-lxc-eth" = values.defaultNetworkConfig // {
      matchConfig = {
        Type = "ether";
        Kind = "veth";
        Name = [
          "eth*"
        ];
      };
      address = with values.hosts.ustetind; [ (ipv4 + "/25") (ipv6 + "/64") ];
    };
    "40-podman-veth" = values.defaultNetworkConfig // {
      matchConfig = {
        Type = "ether";
        Kind = "veth";
        Name = [
          "veth*"
        ];
      };
      DHCP = "yes";
    };
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "24.11";
}
