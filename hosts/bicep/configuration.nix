{ fp, pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    (fp /base)
    ./services/nginx

    ./services/calendar-bot.nix
    #./services/git-mirrors
    ./services/minecraft-heatmap.nix
    ./services/mysql.nix
    ./services/postgres.nix

    ./services/matrix
  ];

  #systemd.network.networks."30-enp6s0f0" = values.defaultNetworkConfig // {
  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    #matchConfig.Name = "enp6s0f0";
    matchConfig.Name = "ens18";
    address = with values.hosts.bicep; [ (ipv4 + "/25") (ipv6 + "/64") ]
      ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
  };
  systemd.network.wait-online = {
    anyInterface = true;
  };

  services.qemuGuest.enable = true;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
