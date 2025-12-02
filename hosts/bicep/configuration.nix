{ fp, pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix

    (fp /base)
    (fp /misc/metrics-exporters.nix)
    ./services/nginx

    #./services/calendar-bot.nix
    #./services/git-mirrors
    #./services/minecraft-heatmap.nix
    #./services/mysql.nix
    ./services/postgres.nix

    #./services/matrix
  ];

  sops.defaultSopsFile = fp /secrets/bicep/bicep.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  #boot.loader.grub.enable = true;
  #boot.loader.grub.device = "/dev/disk/by-id/scsi-3600508b1001cb1a8751c137b30610682";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bicep";

  #systemd.network.networks."30-enp6s0f0" = values.defaultNetworkConfig // {
  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    #matchConfig.Name = "enp6s0f0";
    matchConfig.Name = "ens18";
    address = with values.hosts.bicep; [ (ipv4 + "/25") (ipv6 + "/64") ]
      ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
  };
  systemd.network.wait-online = {
    anyInterface = true;
  };

  # There are no smart devices
  services.smartd.enable = false;
  
  # we are a vm now
  services.qemuGuest.enable = true;  

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.sshguard.enable = true;

  # Do not change, even during upgrades.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "22.11";
}
