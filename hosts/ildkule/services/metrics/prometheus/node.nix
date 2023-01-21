{ config, ... }: let
  cfg = config.services.prometheus;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "node";
    static_configs = [
      {
        targets = [
          "ildkule.pvv.ntnu.no:${toString cfg.exporters.node.port}"
          "microbel.pvv.ntnu.no:9100"
          "isvegg.pvv.ntnu.no:9100"
          "knakelibrak.pvv.ntnu.no:9100"
          "hildring.pvv.ntnu.no:9100"
          "bicep.pvv.ntnu.no:9100"
          "jokum.pvv.ntnu.no:9100"
        ];
      }
    ];
  }];
}
