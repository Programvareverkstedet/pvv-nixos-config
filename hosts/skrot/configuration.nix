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
      owner = "drumknotty";
      group = "drumknotty";
    };
    "worblehat/postgresql/password" = {
      owner = "drumknotty";
      group = "drumknotty";
    };
  };

  services.drumknotty = {
    enable = true;
    kioskMode = true;

    screen = {
      limitWidth = 80;
      limitHeight = 42;
    };

    dibbler = {
      enable = true;
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

    worblehat = {
      enable = true;
      settings = {
        general.quit_allowed = false;
        database = {
          type = "postgresql";
          postgresql = {
            username = "worblehat";
            dbname = "worblehat";
            host = "postgres.pvv.ntnu.no";
            password = config.sops.secrets."worblehat/postgresql/password".path;
          };
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
