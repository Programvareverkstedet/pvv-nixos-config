{ config, pkgs, values, ... }:
{
  imports = [
      ../../base.nix
      ../../misc/metrics-exporters.nix
      ../../misc/rust-motd.nix

      ./services/matrix
      ./services/nginx
    ];

  sops.defaultSopsFile = ../../secrets/jokum/jokum.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;
  
  boot.kernel.enable = false;
  boot.isContainer = true;
  boot.loader.initScript.enable = true;

  networking.hostName = "jokum"; # Define your hostname.

  services.resolved.enable = false;

  networking.interfaces.ens10f1.useDHCP = false;
  networking.interfaces.ens10f1.ipv4 = {
    addresses = [
      {
        address = values.hosts.jokum.ipv4;
        prefixLength = 25;
      }
      {
        address = values.services.turn.ipv4;
        prefixLength = 25;
      }
    ];
  };
  networking.interfaces.ens10f1.ipv6 = {
    addresses = [
      {
        address = values.hosts.jokum.ipv6;
        prefixLength = 64;
      }
      {
        address = values.services.turn.ipv6;
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
