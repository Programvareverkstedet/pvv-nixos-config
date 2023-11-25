{ pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../base.nix
    ../../misc/metrics-exporters.nix
    ../../modules/wackattack-ctf-stockfish

    #./services/keycloak.nix

    # TODO: set up authentication for the following:
    # ./services/website.nix
    ./services/nginx.nix
    ./services/gitea/default.nix
    ./services/webmail
    # ./services/mediawiki.nix
  ];

  sops.defaultSopsFile = ../../secrets/bekkalokk/bekkalokk.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  virtualisation.podman.enable = true;

  networking.hostName = "bekkalokk";

  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bekkalokk; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
