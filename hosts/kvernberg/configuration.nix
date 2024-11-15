{ config, fp, pkgs, values, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (fp /base)
    (fp /misc/metrics-exporters.nix)
    ./disks.nix

    ./services/pvvvvvv
  ];

  sops.defaultSopsFile = fp /secrets/kvernberg/kvernberg.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
 
  networking.hostName = "kvernberg"; # Define your hostname.

  systemd.network.networks."30-all" = values.defaultNetworkConfig // {
    matchConfig.Name = "en*";
    address = with values.hosts.kvernberg; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    
  ];

  # No devices with SMART
  services.smartd.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}
