{ config, fp, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)

      ./services/grzegorz.nix
    ];

  systemd.network.networks."30-eno1" = values.defaultNetworkConfig // {
    matchConfig.Name = "eno1";
    address = with values.hosts.brzeczyszczykiewicz; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  fonts.fontconfig.enable = true;

  # List services that you want to enable:

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
