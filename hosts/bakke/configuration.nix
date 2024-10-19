{ config, pkgs, values, ... }:
{
  imports = [
      ./hardware-configuration.nix
      ../../base
      ../../misc/metrics-exporters.nix
      ./filesystems.nix
    ];

  sops.defaultSopsFile = ../../secrets/bakke/bakke.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bakke";
  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bakke; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  system.stateVersion = "23.05";
}