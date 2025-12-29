{ config, fp, pkgs, lib, values, ... }:

{
  imports = [
    (fp /base)

    ./services/gitea-runners.nix
  ];

  sops.defaultSopsFile = fp /secrets/ustetind/ustetind.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  networking.hostName = "ustetind";

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

  system.stateVersion = "24.11";
}
