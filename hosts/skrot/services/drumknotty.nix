{ config, ... }:
{
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

  systemd.services.drumknotty-screen-session = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  services.roowho2.settings.rwhod.ignoreUsers = [ "drumknotty" ];
}
