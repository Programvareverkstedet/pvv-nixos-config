{ config, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ../../base.nix
      # Users can just import any configuration they want even for non-user things. Improve the users/default.nix to just load some specific attributes if this isn't wanted

      ../../misc/rust-motd.nix

      ./services/matrix
      ./services/nginx
    ];

  sops.defaultSopsFile = ../../secrets/jokum/jokum.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;
  

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" ];

  networking.hostName = "jokum"; # Define your hostname.

  networking.interfaces.ens18.useDHCP = false;
  networking.interfaces.ens18.ipv4 = {
    addresses = [
      {
        address = values.jokum.ipv4;
        prefixLength = 25;
      }
      {
        address = values.turn.ipv4;
        prefixLength = 25;
      }
    ];
  };
  networking.interfaces.ens18.ipv6 = {
    addresses = [
      {
        address = values.jokum.ipv6;
        prefixLength = 64;
      }
      {
        address = values.turn.ipv6;
        prefixLength = 64;
      }
    ];
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
  system.stateVersion = "21.05"; # Did you read the comment?

}
