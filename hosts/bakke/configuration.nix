{ config, pkgs, values, ... }:
{
  imports = [
      ./hardware-configuration.nix
      ../../base
      ./filesystems.nix
    ];

  sops.defaultSopsFile = ../../secrets/bakke/bakke.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  networking.hostId = "99609ffc";
  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bakke; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "24.05";
}
