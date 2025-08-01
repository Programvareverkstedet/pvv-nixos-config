{ config, ... }: let
  cfg = config.services.prometheus;

  mkHostScrapeConfig = name: ports: {
    labels.hostname = name;
    targets = map (port: "${name}.pvv.ntnu.no:${toString port}") ports;
  };

  defaultNodeExporterPort = 9100;
  defaultSystemdExporterPort = 9101;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "base_info";
    static_configs = [
      (mkHostScrapeConfig "ildkule" [ cfg.exporters.node.port cfg.exporters.systemd.port ])
      (mkHostScrapeConfig "bekkalokk" [ defaultNodeExporterPort defaultSystemdExporterPort ])
      (mkHostScrapeConfig "kommode" [ defaultNodeExporterPort defaultSystemdExporterPort ])
      (mkHostScrapeConfig "bicep" [ defaultNodeExporterPort defaultSystemdExporterPort ])
      (mkHostScrapeConfig "brzeczyszczykiewicz" [ defaultNodeExporterPort defaultSystemdExporterPort ])
      (mkHostScrapeConfig "georg" [ defaultNodeExporterPort defaultSystemdExporterPort ])
      (mkHostScrapeConfig "ustetind" [ defaultNodeExporterPort defaultSystemdExporterPort ])

      (mkHostScrapeConfig "hildring" [ defaultNodeExporterPort ])
      (mkHostScrapeConfig "isvegg" [ defaultNodeExporterPort ])
      (mkHostScrapeConfig "microbel" [ defaultNodeExporterPort ])
    ];
  }];
}
