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

  sops.secrets = {
    "dibbler/postgresql/password" = {
      owner = "dibbler";
      group = "dibbler";
    };
  };

  services.dibbler = {
    enable = true;
    kioskMode = true;
    limitScreenWidth = 80;
    limitScreenHeight = 42;

    settings = {
      general.quit_allowed = false;
      database = {
        type = "postgresql";
        postgresql = {
          username = "pvv_vv";
          dbname = "pvv_vv";
          host = "postgres.pvv.ntnu.no";
          password_file = config.sops.secrets."dibbler/postgresql/password".path;
        };
      };
    };
  };

  systemd.services."serial-getty@ttyUSB0" = lib.mkIf (!config.virtualisation.isVmVariant) {
    enable = true;
    wantedBy = [ "getty.target" ]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };

  system.stateVersion = "25.11"; # Did you read the comment? Nah bro
}
