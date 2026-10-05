{ config, ... }: let
  cfg = config.services.prometheus;

  mkHostScrapeConfig = name: ports: {
    labels.hostname = name;
    targets = map (port: "${name}.pvv.ntnu.no:${toString port}") ports;
  };

  nixosMachines = [
    "ildkule"
    "bekkalokk"
    "bicep"
    "brzeczyszczykiewicz"
    "georg"
    "gluttony"
    "kommode"
    "lupine-1"
    "lupine-2"
    "lupine-3"
    "lupine-4"
    "lupine-5"
    "temmie"
    "wenche"
  ];

  # NOTE: VMs don't run smartctl-exporter
  smartMachines = [
    "bekkalokk"
    "bicep"
    "brzeczyszczykiewicz"
    "georg"
    "lupine-1"
    "lupine-2"
    "lupine-3"
    "lupine-4"
    "lupine-5"
  ];

  defaultNodeExporterPort = 9100;
in {
  services.prometheus.scrapeConfigs = [
    {
      job_name = "nixos-node";
      scheme = "https";
      metrics_path = "/prometheus-node-exporter/metrics";
      static_configs = map (name: {
        labels.hostname = name;
        targets = [ "${name}.pvv.ntnu.no:443" ];
      }) nixosMachines;
    }
    {
      job_name = "nixos-systemd";
      scheme = "https";
      metrics_path = "/prometheus-systemd-exporter/metrics";
      static_configs = map (name: {
        labels.hostname = name;
        targets = [ "${name}.pvv.ntnu.no:443" ];
      }) nixosMachines;
    }
    {
      job_name = "nixos-smartctl";
      scheme = "https";
      metrics_path = "/prometheus-smartctl-exporter/metrics";
      static_configs = map (name: {
        labels.hostname = name;
        targets = [ "${name}.pvv.ntnu.no:443" ];
      }) smartMachines;
    }
    {
      job_name = "nixos-flake-input";
      scheme = "https";
      metrics_path = "/prometheus-nixos-flake-input-exporter/metrics";
      static_configs = map (name: {
        labels.hostname = name;
        targets = [ "${name}.pvv.ntnu.no:443" ];
      }) nixosMachines;
    }
    {
      job_name = "nixos-fluent-bit";
      scheme = "https";
      metrics_path = "/prometheus-fluent-bit-exporter/metrics";
      static_configs = map (name: {
        labels.hostname = name;
        targets = [ "${name}.pvv.ntnu.no:443" ];
      }) nixosMachines;
    }
    {
      job_name = "non-nixos-node";
      scheme = "http";
      metrics_path = "/metrics";
      static_configs = [
        (mkHostScrapeConfig "hildring" [ defaultNodeExporterPort ])
        (mkHostScrapeConfig "isvegg" [ defaultNodeExporterPort ])
        (mkHostScrapeConfig "microbel" [ defaultNodeExporterPort ])
      ];
    }
  ];
}
