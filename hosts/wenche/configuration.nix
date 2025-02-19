{ config, fp, pkgs, values, lib, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)
      (fp /misc/metrics-exporters.nix)

      (fp /misc/builder.nix)
    ];

  sops.defaultSopsFile = fp /secrets/wenche/wenche.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "wenche"; # Define your hostname.

  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.wenche; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  system.stateVersion = "24.11"; # Did you read the comment?
}
