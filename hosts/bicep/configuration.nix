{ fp, lib, values, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix

    (fp /base)
    # ./services/nginx

    # ./services/calendar-bot.nix
    #./services/git-mirrors
    # ./services/minecraft-heatmap.nix
    # ./services/mysql
    # ./services/postgresql

    # ./services/matrix
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };

  systemd.network.networks."30-enp6s0f3" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp6s0f3";
    address = with values.hosts.bicep; [ (ipv4 + "/25") (ipv6 + "/64") ]
      ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
  };
  systemd.network.wait-online = {
    anyInterface = true;
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "26.05";
}
