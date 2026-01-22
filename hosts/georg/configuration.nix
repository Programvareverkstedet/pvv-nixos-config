{ config, fp, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)

      (fp /modules/grzegorz.nix)
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "georg";

  systemd.network.networks."30-eno1" = values.defaultNetworkConfig // {
    matchConfig.Name = "eno1";
    address = with values.hosts.georg; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  # List services that you want to enable:



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


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
