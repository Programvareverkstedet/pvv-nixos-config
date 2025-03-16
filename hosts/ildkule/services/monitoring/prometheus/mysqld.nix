{ config, ... }: let
  cfg = config.services.prometheus;
in {
  sops = {
    secrets."config/mysqld_exporter_password" = { };

    templates."mysqld_exporter.conf" = {
      restartUnits = [ "prometheus-mysqld-exporter.service" ];
      content = let
        inherit (config.sops) placeholder;
      in ''
        [client]
        host = bicep.pvv.ntnu.no
        port = 3306
        user = prometheus_mysqld_exporter
        password = ${placeholder."config/mysqld_exporter_password"}
      '';
    };
  };

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
      configFile = config.sops.templates."mysqld_exporter.conf".path;
    };
  };
}
