{ config, pkgs, ... }:
let
  unstable = import <nixos-unstable> { };
in
{
  imports = [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./services/matrix
      ./services/nginx
      ./services/postgres
    ];


  nixpkgs.config.packageOverrides = pkgs: {
    inherit unstable;
  };

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" ];

  networking.hostName = "jokum"; # Define your hostname.
  networking.domain = "pvv.ntnu.no";

  # Set your time zone.
  time.timeZone = "Europe/Oslo";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
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

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "no";
  };


  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.jane = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  # };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    git
    vim
    nano
    wget
    tmux
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}

