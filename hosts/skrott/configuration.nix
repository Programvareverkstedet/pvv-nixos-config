{ fp, config, pkgs, values, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    # ./hardware-configuration.nix
    (fp /base.nix)
    (fp /misc/metrics-exporters.nix)
    ./services/dibbler.nix
  ];
  
  sops.defaultSopsFile = ../../secrets/skrott/skrott.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "skrott";

  systemd.network.networks."30-yolo" = values.defaultNetworkConfig // {
    matchConfig.Name = "*";
    address = with values.hosts.skrott; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  system.stateVersion = "24.11";
}
