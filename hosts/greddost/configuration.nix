# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ../../hardware-configuration.nix

      ../../base.nix

      ../../services/minecraft
    ];


  services.minecraft-server = {
    enable = false;
    eula = true;
    package = pkgs.callPackage ../../pkgs/minecraft-server-fabric { inherit (pkgs.unstable) minecraft-server; };
    dataDir =  "/fast/minecraft"; #"/fast/minecraft";
    jvmOpts = "-Xms10G -Xmx10G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC  -XX:+DisableExplicitGC  -XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled";

    declarative = true;
    serverProperties = {
      view-distance = 32;
      gamemode = 1;
      enable-rcon = true;
      "rcon.password" = "pvv";
    };
  };


  nixpkgs.config.packageOverrides = pkgs: {
    unstable = (import <nixos-unstable>) { };
  };

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "greddost"; # Define your hostname.

  networking.interfaces.ens18.useDHCP = false;

  networking.defaultGateway = "129.241.210.129";
  networking.interfaces.ens18.ipv4 = {
    addresses = [
      {
        address = "129.241.210.174";
        prefixLength = 25;
      }
    ];
  };
  networking.interfaces.ens18.ipv6 = {
    addresses = [
      {
        address = "2001:700:300:1900::174";
        prefixLength = 64;
      }
    ];
  };
  networking.nameservers = [ "129.241.0.200" "129.241.0.201" ];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}

