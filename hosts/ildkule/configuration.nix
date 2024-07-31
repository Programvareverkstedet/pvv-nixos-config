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

  # Main connection, using the global/floatig IP, for communications with the world
  systemd.network.networks."30-ntnu-global" = values.openstackGlobalNetworkConfig // {
    matchConfig.Name = "ens4";

    # Add the global addresses in addition to the local address learned from DHCP
    addresses = [
      { addressConfig.Address = "${values.hosts.ildkule.ipv4_global}/32"; }
      { addressConfig.Address = "${values.hosts.ildkule.ipv6_global}/128"; }
    ];
  };

  # Secondary connection only for use within the university network
  systemd.network.networks."40-ntnu-internal" = values.openstackLocalNetworkConfig // {
    matchConfig.Name = "ens3";
    # Add the ntnu-internal addresses in addition to the local address learned from DHCP
    addresses = [
      { addressConfig.Address = "${values.hosts.ildkule.ipv4}/32"; }
      { addressConfig.Address = "${values.hosts.ildkule.ipv6}/128"; }
    ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  system.stateVersion = "23.11"; # Did you read the comment?

}
