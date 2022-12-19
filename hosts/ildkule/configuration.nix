{ config, pkgs, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ../../base.nix
      ../../misc/rust-motd.nix
      ../../misc/metrics-exporters.nix
      # Users can just import any configuration they want even for non-user things. Improve the users/default.nix to just load some specific attributes if this isn't wanted
      ./services/metrics
    ];

  sops.defaultSopsFile = ../../secrets/ildkule/ildkule.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ildkule"; # Define your hostname.

  networking.interfaces.ens18.useDHCP = false;

  networking.defaultGateway = "129.241.210.129";
  networking.interfaces.ens18.ipv4 = {
    addresses = [
      {
        address = "129.241.210.187";
        prefixLength = 25;
      }
    ];
  };
  networking.interfaces.ens18.ipv6 = {
    addresses = [
      {
        address = "2001:700:300:1900::187";
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
  system.stateVersion = "21.11"; # Did you read the comment?

}
