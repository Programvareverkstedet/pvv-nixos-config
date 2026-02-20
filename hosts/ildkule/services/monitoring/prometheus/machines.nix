{ config, ... }:
let
  cfg = config.services.prometheus;

  mkHostScrapeConfig = name: ports: {
    labels.hostname = name;
    targets = map (port: "${name}.pvv.ntnu.no:${toString port}") ports;
  };

  defaultNodeExporterPort = 9100;
  defaultSystemdExporterPort = 9101;
  defaultNixosExporterPort = 9102;
in
{
  services.prometheus.scrapeConfigs = [
    {
      job_name = "base_info";
      static_configs = [
        (mkHostScrapeConfig "ildkule" [
          cfg.exporters.node.port
          cfg.exporters.systemd.port
          defaultNixosExporterPort
        ])

        (mkHostScrapeConfig "bekkalokk" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "bicep" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "brzeczyszczykiewicz" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "georg" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "gluttony" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "kommode" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "lupine-1" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "lupine-2" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "lupine-3" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "lupine-4" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "lupine-5" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "temmie" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "ustetind" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])
        (mkHostScrapeConfig "wenche" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
          defaultNixosExporterPort
        ])

        (mkHostScrapeConfig "skrott" [
          defaultNodeExporterPort
          defaultSystemdExporterPort
        ])

        (mkHostScrapeConfig "hildring" [ defaultNodeExporterPort ])
        (mkHostScrapeConfig "isvegg" [ defaultNodeExporterPort ])
        (mkHostScrapeConfig "microbel" [ defaultNodeExporterPort ])
      ];
    }
  ];
}
