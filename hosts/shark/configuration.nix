{ config, fp, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)
    ];

  sops.defaultSopsFile = fp /secrets/shark/shark.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.shark; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "23.05";
}
