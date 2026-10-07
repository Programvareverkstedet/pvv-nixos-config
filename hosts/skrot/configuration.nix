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
    # `systemd.services."serial-getty@" is a thing, but not `systemd.services."serial-getty@ttyUSB0"`,
    # so unless we specifically request an `override.conf`, this would've been its own unit.
    overrideStrategy = "asDropin";
    wantedBy = [ "getty.target" ]; # to start at boot

    serviceConfig.ExecStart = config.systemd.services."serial-getty@".serviceConfig.ExecStart;
  };

  system.stateVersion = "25.11"; # Did you read the comment? Nah bro
}
