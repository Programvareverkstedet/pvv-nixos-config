{ config, fp, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)

      ./services/nfs-mounts.nix
    ];

  # sops.defaultSopsFile = fp /secrets/shark/shark.yaml;
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # sops.age.generateKey = true;


  networking.hostName = "temmie"; # Define your hostname.

  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.temmie; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # List services that you want to enable:

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
