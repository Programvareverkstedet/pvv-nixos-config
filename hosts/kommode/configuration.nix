{ pkgs, values, fp, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (fp /base)
    ./disks.nix

    ./services/gitea
    ./services/nginx.nix
  ];

  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.kommode; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  services.btrfs.autoScrub.enable = true;

  services.qemuGuest.enable = true;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "24.11";
}
