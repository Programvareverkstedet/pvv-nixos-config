{ pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../base.nix

    ./services/postgres.nix
  ];

  sops.defaultSopsFile = ../../secrets/bicep/bicep.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bicep";

  # systemd.network.networks."30-ens33" = values.defaultNetworkConfig // {
  #   matchConfig.Name = "ens33";
  #   address = with values.hosts.bekkalokk; [ (ipv4 + "/25") (ipv6 + "/64") ];
  # };

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
