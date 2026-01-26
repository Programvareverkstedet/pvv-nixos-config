{ config, fp, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)

      (fp /modules/grzegorz.nix)
    ];

  systemd.network.networks."30-eno1" = values.defaultNetworkConfig // {
    matchConfig.Name = "eno1";
    address = with values.hosts.georg; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  services.spotifyd = {
    enable = true;
    settings.global = {
      device_name = "georg";
      use_mpris = false;
      #dbus_type = "system";
      #zeroconf_port = 1234;
    };
  };

  networking.firewall.allowedTCPPorts = [
    # config.services.spotifyd.settings.zeroconf_port
    5353 # spotifyd is its own mDNS service wtf
  ];

  fonts.fontconfig.enable = true;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
