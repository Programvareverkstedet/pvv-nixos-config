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

  console = {
    keyMap = "no";
    font = lib.mkForce "lat1-16";
    earlySetup = true;
  };

  i18n.defaultCharset = lib.mkForce "ISO-8859-1";
  i18n.defaultLocale = lib.mkForce "en_US";
  i18n.extraLocales = [
    "en_US/ISO-8859-1"
    "nb_NO/ISO-8859-1"
  ];

  systemd.services."serial-getty@ttyUSB0" = lib.mkIf (!config.virtualisation.isVmVariant) {
    enable = true;
    wantedBy = [ "getty.target" ]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };

  system.stateVersion = "25.11"; # Did you read the comment? Nah bro
}
