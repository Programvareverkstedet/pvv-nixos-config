{ pkgs, values, fp, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (fp /base)
    (fp /misc/metrics-exporters.nix)
  ];

  sops.defaultSopsFile = fp /secrets/kommode/kommode.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kommode"; # Define your hostname.

  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.kommode; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  services.btrfs.autoScrub.enable = true;

  environment.systemPackages = with pkgs; [];

  system.stateVersion = "24.11";
}

