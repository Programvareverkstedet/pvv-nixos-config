{
  config,
  pkgs,
  lib,
  ...
}:
let
  mainCfg = config.services.drumknotty;
  cfg = config.services.drumknotty.dibbler;

  format = pkgs.formats.toml { };
in
{
  options.services.drumknotty.dibbler = {
    enable = lib.mkEnableOption "";

    package = lib.mkPackageOption pkgs "dibbler" { };

    settings = lib.mkOption {
      description = "Configuration for dibbler";
      default = { };
      type = lib.types.submodule {
        freeformType = format.type;
      };
    };

    createLocalDatabase = lib.mkEnableOption "" // {
      description = ''
        Whether to set up a local postgres database automatically.

        ::: {.note}
        You must set up postgres manually before enabling this option.
        :::
      '';
    };
  };

  config = lib.mkIf (mainCfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.createLocalDatabase -> config.services.postgresql.enable;
        message = "PostgreSQL must be enabled for dibbler to create a local database";
      }
    ];

    environment.systemPackages = [ cfg.package ];
    environment.etc."dibbler/dibbler.toml".source = format.generate "dibbler.toml" cfg.settings;

    services.drumknotty.dibbler.settings = {
      limits = {
        low_credit_warning_limit = lib.mkDefault (-100);
        user_recent_transaction_limit = lib.mkDefault 100;
      };

      printer = {
        label_type = lib.mkDefault "62";
        label_rotate = lib.mkDefault false;
      };

      database = {
        type = lib.mkIf cfg.createLocalDatabase "postgresql";
        postgresql = {
          username = lib.mkDefault "dibbler";
          dbname = lib.mkDefault "dibbler";

          host = lib.mkIf cfg.createLocalDatabase "/run/postgresql";
        };
      };
    };

    services.drumknotty.dibbler.settings.general = lib.mkIf mainCfg.kioskMode {
      quit_allowed = false;
      stop_allowed = false;
    };

    services.postgresql = lib.mkIf cfg.createLocalDatabase {
      authentication = ''
        local ${cfg.settings.database.postgresql.dbname} ${cfg.settings.database.postgresql.username} peer map=${cfg.settings.database.postgresql.username}
      '';
      identMap = ''
        ${cfg.settings.database.postgresql.username} drumknotty ${cfg.settings.database.postgresql.username}
      '';
      ensureDatabases = [ cfg.settings.database.postgresql.dbname ];
      ensureUsers = [{
        name = cfg.settings.database.postgresql.username;
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }];
    };

    systemd.services.dibbler-setup-database = lib.mkIf cfg.createLocalDatabase {
      description = "Dibbler database setup";

      wantedBy = [ "default.target" ];
      requiredBy = [ "drumknotty-screen-session.service" ];
      before = [ "drumknotty-screen-session.service" ];
      after = [ "postgresql.service" ];

      unitConfig = {
        ConditionPathExists = "!/var/lib/dibbler/.db-setup-done";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cfg.package} --config /etc/dibbler/dibbler.toml create-db";
        ExecStartPost = "${lib.getExe' pkgs.coreutils "touch"} /var/lib/dibbler/.db-setup-done";
        StateDirectory = "dibbler";

        User = "drumknotty";
        Group = "drumknotty";
      };
    };
  };
}
