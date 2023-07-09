{ config, unstable, ... }: let
  cfg = config.services.prometheus;
in {
  sops.secrets."config/mysqld_exporter" = { };

  services.prometheus = {
    scrapeConfigs = [{
      job_name = "mysql";
      scheme = "http";
      metrics_path = cfg.exporters.mysqld.telemetryPath;
      static_configs = [
        {
          targets = [
            "localhost:${toString cfg.exporters.mysqld.port}"
          ];
        }
      ];
    }];

    exporters.mysqld = {
      enable = true;
      configFilePath = config.sops.secrets."config/mysqld_exporter".path;
    };
  };
}
