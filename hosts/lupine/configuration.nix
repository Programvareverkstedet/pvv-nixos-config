{ config, fp, pkgs, values, ... }:
{
  imports = [
    ./hardware/${config.networking.hostname}.nix

    (fp /base)
    (fp /misc/metrics-exporters.nix)
  ];

  sops.defaultSopsFile = fp /secrets/lupine/lupine.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.network.networks."30-enp6s0f0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp6s0f0";
    address = with values.hosts.lupine; [ (ipv4 + "/25") (ipv6 + "/64") ]
      ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
  };
  systemd.network.wait-online = {
    anyInterface = true;
  };

  # There are no smart devices
  services.smartd.enable = false;

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "24.11";
}
