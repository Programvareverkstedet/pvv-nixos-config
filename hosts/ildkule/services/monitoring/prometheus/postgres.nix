{ pkgs, lib, config, values, ... }: let
  cfg = config.services.prometheus;
in {
  sops.secrets = {
    "keys/postgres/postgres_exporter_env" = {};
    "keys/postgres/postgres_exporter_knakelibrak_env" = {};
  };

  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "postgres";
        scrape_interval = "15s";
        static_configs = [{
          targets = [ "localhost:${toString cfg.exporters.postgres.port}" ];
          labels = {
            server = "bicep";
          };
        }];
      }
      {
        job_name = "postgres-knakelibrak";
        scrape_interval = "15s";
        static_configs = [{
          targets = [ "localhost:${toString (cfg.exporters.postgres.port + 1)}" ];
          labels = {
            server = "knakelibrak";
          };
        }];
      }
    ];

    exporters.postgres = {
      enable = true;
      extraFlags = [ "--auto-discover-databases" ];
      environmentFile = config.sops.secrets."keys/postgres/postgres_exporter_env".path;
    };
  };

  systemd.services.prometheus-postgres-exporter-knakelibrak.serviceConfig = let
    localCfg = config.services.prometheus.exporters.postgres; 
  in lib.recursiveUpdate config.systemd.services.prometheus-postgres-exporter.serviceConfig {
      EnvironmentFile = config.sops.secrets."keys/postgres/postgres_exporter_knakelibrak_env".path;
      ExecStart = ''
        ${pkgs.prometheus-postgres-exporter}/bin/postgres_exporter \
          --web.listen-address ${localCfg.listenAddress}:${toString (localCfg.port + 1)} \
          --web.telemetry-path ${localCfg.telemetryPath} \
          ${lib.concatStringsSep " \\\n  " localCfg.extraFlags}
      '';
    };
}
