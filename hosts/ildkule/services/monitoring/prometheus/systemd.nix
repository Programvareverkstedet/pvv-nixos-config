{ config, ... }: let
  cfg = config.services.prometheus;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "systemd";
    static_configs = [
      {
        targets = [
          "ildkule.pvv.ntnu.no:${toString cfg.exporters.node.port}"
          "bicep.pvv.ntnu.no:9101"
          "bekkalokk.pvv.ntnu.no:9101"
          "brzeczyszczykiewicz.pvv.ntnu.no:9101"
          "georg.pvv.ntnu.no:9101"
        ];
      }
    ];
  }];
}
