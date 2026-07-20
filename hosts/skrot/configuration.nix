{
  fp,
  lib,
  config,
  values,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./disk-config.nix
    (fp /base)

    ./services/drumknotty.nix
  ];

  boot.consoleLogLevel = 0;

  sops.defaultSopsFile = fp /secrets/skrot/skrot.yaml;

  systemd.network.networks."enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.skrot; [
      (ipv4 + "/25")
      (ipv6 + "/64")
    ];
  };

  systemd.services."serial-getty@ttyUSB0" = lib.mkIf (!config.virtualisation.isVmVariant) {
    enable = true;
    wantedBy = [ "getty.target" ]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };

  system.stateVersion = "25.11"; # Did you read the comment? Nah bro
}
