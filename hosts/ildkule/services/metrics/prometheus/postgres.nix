{ config, values, ... }: let
  cfg = config.services.prometheus;
in {
  sops.secrets."keys/postgres/postgres_exporter_env" = {
    
  };

  services.prometheus = {
    scrapeConfigs = [{
      job_name = "postgres";
      scrape_interval = "15s";
      static_configs = [{
        targets = [ "localhost:${toString cfg.exporters.postgres.port}" ];
      }];
    }];

    exporters.postgres = {
      enable = true;
      extraFlags = [ "--auto-discover-databases" ];
      environmentFile = config.sops.secrets."keys/postgres/postgres_exporter_env".path;
    };
  };
}
