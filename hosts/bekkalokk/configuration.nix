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

  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bekkalokk; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  services.btrfs.autoScrub.enable = true;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
