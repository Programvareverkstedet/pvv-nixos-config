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

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
   };
  };

  networking.hostName = "bakke";
  networking.hostId = "99609ffc";
  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bakke; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  system.stateVersion = "23.05";
}
