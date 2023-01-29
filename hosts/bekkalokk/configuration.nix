{ pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../base.nix

    # TODO: set up authentication for the following:
    # ./services/website/website.nix
    # ./services/website/nginx.nix
    # ./services/website/gitea.nix
    # ./services/website/mediawiki.nix
  ];

  sops.defaultSopsFile = ../../secrets/bekkalokk/bekkalokk.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bekkalokk";

  networking.interfaces.ens33 = {
    useDHCP = false;

    ipv4.addresses = [{
      address = values.hosts.bekkalokk.ipv4;
      prefixLength = 25;
    }];

    ipv6.addresses = [{
      address = values.hosts.bekkalokk.ipv6;
      prefixLength = 64;
    }];
  };

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
