{ fp, values, lupineName, ... }:
{
  imports = [
    ./hardware-configuration/${lupineName}.nix

    (fp /base)

    ./services/gitea-runner.nix
  ];

  sops.defaultSopsFile = fp /secrets/lupine/lupine.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  systemd.network.networks."30-enp0s31f6" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp0s31f6";
    address = with values.hosts.${lupineName}; [ (ipv4 + "/25") (ipv6 + "/64") ];
    networkConfig.LLDP = false;
  };
  systemd.network.wait-online = {
    anyInterface = true;
  };

  # There are no smart devices
  services.smartd.enable = false;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.05";
}
