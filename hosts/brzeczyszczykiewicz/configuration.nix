{ config, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../base
      ../../misc/metrics-exporters.nix

      ./services/grzegorz.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "brzeczyszczykiewicz";

  systemd.network.networks."30-eno1" = values.defaultNetworkConfig // {
    matchConfig.Name = "eno1";
    address = with values.hosts.brzeczyszczykiewicz; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  # List services that you want to enable:

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
