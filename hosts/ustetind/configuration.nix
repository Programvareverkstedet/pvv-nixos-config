{ config, fp, pkgs, lib, values, ... }:

{
  imports = [
    (fp /base)
    (fp /misc/metrics-exporters.nix)

    ./services/gitea-runners.nix
  ];

  sops.defaultSopsFile = fp /secrets/ustetind/ustetind.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  networking.hostName = "ustetind";

  networking.useHostResolvConf = lib.mkForce false;
  # systemd.network.enable = lib.mkForce false;
  # networking.useDHCP = lib.mkForce true;
  # networking.address = with values.hosts.georg; [ (ipv4 + "/25") (ipv6 + "/64") ];

  systemd.network.networks."30-lxc-veth" = values.defaultNetworkConfig // {
    matchConfig = {
      Type = "ether";
      Kind = "veth";
      Name = [
        "eth*"
      ];
    };
    address = with values.hosts.ustetind; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  system.stateVersion = "24.11";
}
