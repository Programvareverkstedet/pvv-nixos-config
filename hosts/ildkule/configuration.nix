{ config, fp, pkgs, lib, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)

      ./services/monitoring
      ./services/nginx
      ./services/journald-remote.nix
    ];

  sops.defaultSopsFile = fp /secrets/ildkule/ildkule.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.grub.device = "/dev/vda";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  # Openstack Neutron and systemd-networkd are not best friends, use something else:
  systemd.network.enable = lib.mkForce false;
  networking = let
    hostConf = values.hosts.ildkule;
  in {
    hostName = "ildkule";
    tempAddresses = "disabled";
    useDHCP = lib.mkForce true;

    search = values.defaultNetworkConfig.domains;
    nameservers = values.defaultNetworkConfig.dns;
    defaultGateway.address = hostConf.ipv4_internal_gw;

    interfaces."ens4" = {
      ipv4.addresses = [
        { address = hostConf.ipv4;          prefixLength = 32; }
        { address = hostConf.ipv4_internal; prefixLength = 24; }
      ];
      ipv6.addresses = [
        { address = hostConf.ipv6;          prefixLength = 64; }
      ];
    };
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  # No devices with SMART
  services.smartd.enable = false;

  system.stateVersion = "23.11"; # Did you read the comment?

}
