{ pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../base
    ../../misc/metrics-exporters.nix

    ./services/bluemap/default.nix
    ./services/gitea/default.nix
    ./services/idp-simplesamlphp
    ./services/kerberos
    ./services/mediawiki
    ./services/nginx.nix
    ./services/phpfpm.nix
    ./services/vaultwarden.nix
    ./services/webmail
    ./services/website
    ./services/well-known
  ];

  sops.defaultSopsFile = ../../secrets/bekkalokk/bekkalokk.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bekkalokk";

  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bekkalokk; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  services.btrfs.autoScrub.enable = true;

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
