{ fp, pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    (fp /base)

    ./services/alps.nix
    ./services/bluemap.nix
    ./services/idp-simplesamlphp
    ./services/kerberos.nix
    ./services/mediawiki
    ./services/nginx.nix
    ./services/phpfpm.nix
    ./services/vaultwarden.nix
    ./services/webmail
    ./services/website
    ./services/well-known
    ./services/qotd
  ];

  sops.defaultSopsFile = fp /secrets/bekkalokk/bekkalokk.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bekkalokk; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  services.btrfs.autoScrub.enable = true;

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
