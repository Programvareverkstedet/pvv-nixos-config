{ pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../base.nix

    ./services/postgres.nix
    ./services/jokum.nix
  ];

  sops.defaultSopsFile = ../../secrets/bicep/bicep.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/disk/by-id/scsi-3600508b1001cb1a8751c137b30610682";

  networking.hostName = "bicep";

  systemd.network.networks."30-enp6s0f0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp6s0f0";
    address = with values.hosts.bicep; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
