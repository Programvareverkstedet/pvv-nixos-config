{
  config,
  pkgs,
  lib,
  ...
}:
let
  mainCfg = config.services.drumknotty;
  cfg = config.services.drumknotty.worblehat;

  format = pkgs.formats.toml { };
in
{
  options.services.drumknotty.worblehat = {
    enable = lib.mkEnableOption "";

    package = lib.mkPackageOption pkgs "worblehat" { };

    settings = lib.mkOption {
      description = "Configuration for worblehat";
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

    deadline-daemon = {
      enable = lib.mkEnableOption "" // {
        description = ''
          Whether to enable the worblehat deadline-daemon service,
          which periodically checks for upcoming deadlines and notifies users.

          Note that this service is independent of the main worblehat service,
          and must be enabled separately.
        '';
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        description = ''
          How often to trigger rendering the map,
          in the format of a systemd timer onCalendar configuration.

          See {manpage}`systemd.timer(5)`.
        '';
        default = "*-*-* 10:15:00";
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.createLocalDatabase -> config.services.postgresql.enable;
          message = "PostgreSQL must be enabled for worblehat to create a local database";
        }
      ];

      # TODO: Retrieve defaults from the example config file in the project code.
      services.drumknotty.worblehat.settings = {
        logging = {
          debug = lib.mkDefault true;
          debug_sql = lib.mkDefault false;
        };

        database = {
          type = lib.mkDefault "sqlite";
          sqlite.path = lib.mkDefault "./worblehat.sqlite";
          postgresql = {
            host = lib.mkDefault "localhost";
            port = lib.mkDefault 5432;
            username = lib.mkDefault "worblehat";
            password = lib.mkDefault "/var/lib/worblehat/db-password";
            database = lib.mkDefault "worblehat";
          };
        };

        flask = {
          TESTING = lib.mkDefault true;
          DEBUG = lib.mkDefault true;
          FLASK_ENV = lib.mkDefault "development";
          SECRET_KEY = lib.mkDefault "change-me";
        };

        smtp = {
          enabled = lib.mkDefault false;
          host = lib.mkDefault "smtp.pvv.ntnu.no";
          port = lib.mkDefault 587;
          username = lib.mkDefault "worblehat";
          password = lib.mkDefault "/var/lib/worblehat/smtp-password";
          from = lib.mkDefault "worblehat@pvv.ntnu.no";
          subject_prefix = lib.mkDefault "[Worblehat]";
        };

        deadline_daemon = {
          enabled = lib.mkDefault true;
          dryrun = lib.mkDefault false;
          warn_days_before_borrowing_deadline = lib.mkDefault [
            5
            1
          ];
          days_before_queue_position_expires = lib.mkDefault 14;
          warn_days_before_expiring_queue_position_deadline = lib.mkDefault [
            3
            1
          ];
        };
      };
    }

    (lib.mkIf ((mainCfg.enable && cfg.enable) || cfg.deadline-daemon.enable) {
      environment.systemPackages = [ cfg.package ];
      environment.etc."worblehat/config.toml".source = format.generate "worblehat-config.toml" cfg.settings;
    })

    (lib.mkIf (mainCfg.enable && cfg.enable) {
      services.drumknotty.worblehat.settings.general = lib.mkIf mainCfg.kioskMode {
        quit_allowed = false;
        stop_allowed = false;
      };

      services.drumknotty.worblehat.settings.database = lib.mkIf cfg.createLocalDatabase {
        type = "postgresql";
        postgresql.host = "/run/postgresql";
      };

      services.postgresql = lib.mkIf cfg.createLocalDatabase {
        authentication = ''
          local ${cfg.settings.database.postgresql.database} ${cfg.settings.database.postgresql.username} peer map=${cfg.settings.database.postgresql.username}
        '';
        identMap = ''
          ${cfg.settings.database.postgresql.username} drumknotty ${cfg.settings.database.postgresql.username}
        '';
        ensureDatabases = [ cfg.settings.database.postgresql.database ];
        ensureUsers = [{
          name = cfg.settings.database.postgresql.username;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }];
      };

      systemd.services.worblehat-setup-database = lib.mkIf cfg.createLocalDatabase {
        description = "Worblehat database setup";

        wantedBy = [ "default.target" ];
        requiredBy = [ "drumknotty-screen-session.service" ];
        before = [ "drumknotty-screen-session.service" ];
        after = [ "postgresql.service" ];

        unitConfig = {
          ConditionPathExists = "!/var/lib/worblehat/.db-setup-done";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe cfg.package} --config /etc/worblehat/config.toml create-db";
          ExecStartPost = "${lib.getExe' pkgs.coreutils "touch"} /var/lib/worblehat/.db-setup-done";
          StateDirectory = "worblehat";

          User = "drumknotty";
          Group = "drumknotty";
        };
      };
    })

    (lib.mkIf cfg.deadline-daemon.enable {
      systemd.timers.worblehat-deadline-daemon = lib.mkIf cfg.deadline-daemon.enable {
        description = "Worblehat Deadline Daemon";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.deadline-daemon.onCalendar;
          Persistent = true;
        };
      };

      systemd.services.worblehat-deadline-daemon = lib.mkIf cfg.deadline-daemon.enable {
        description = "Worblehat Deadline Daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";

          ExecStart =
            let
              worblehatArgs = lib.cli.toCommandLineShellGNU { } {
                config = "/etc/worblehat/config.toml";
              };
            in
            "${lib.getExe cfg.package} ${worblehatArgs} deadline-daemon";

          User = "drumknotty";
          Group = "drumknotty";
        };
      };
    })
  ];
}
