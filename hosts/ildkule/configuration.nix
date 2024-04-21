{ config, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../base.nix
      ../../misc/metrics-exporters.nix

      ./services/monitoring
      ./services/nginx
    ];

  sops.defaultSopsFile = ../../secrets/ildkule/ildkule.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.grub.device = "/dev/vda";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "ildkule"; # Define your hostname.
  systemd.network.networks."30-all" = values.defaultNetworkConfig // {
    matchConfig.Name = "en*";
    DHCP = "yes";
    gateway = [ ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  system.stateVersion = "23.11"; # Did you read the comment?

}
