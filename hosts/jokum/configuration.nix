{ config, pkgs, ... }:
let
  unstable = import <nixos-unstable> { };
in
{
  imports = [
      # Include the results of the hardware scan.
      ../../hardware-configuration.nix

      ../../base.nix
      # Users can just import any configuration they want even for non-user things. Improve the users/default.nix to just load some specific attributes if this isn't wanted

      ../../modules/rust-motd.nix

      ../../services/matrix
      ../../services/nginx
      ../../services/postgres
    ];


  # Allow accessing <nixos-unstable> through pkgs.unstable.*
  nixpkgs.config.packageOverrides = pkgs: {
    inherit unstable;
  };

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" ];

  networking.hostName = "jokum"; # Define your hostname.

  networking.interfaces.ens18.useDHCP = false;

  networking.defaultGateway = "129.241.210.129";
  networking.interfaces.ens18.ipv4 = {
    addresses = [
      {
        address = "129.241.210.169";
        prefixLength = 25;
      }
    ];
  };
  networking.interfaces.ens18.ipv6 = {
    addresses = [
      {
        address = "2001:700:300:1900::169";
        prefixLength = 64;
      }
    ];
  };
  networking.nameservers = [ "129.241.0.200" "129.241.0.201" ];

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
  system.stateVersion = "21.05"; # Did you read the comment?

}

