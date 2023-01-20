{ config, pkgs, ... }:

let
  cfg = config.services.prometheus;
in {
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9001;

    scrapeConfigs = [
      {
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
      }
      {
        job_name = "synapse";
        scrape_interval = "15s";
        scheme = "https";
        http_sd_configs = [
          {
            url = "https://matrix.pvv.ntnu.no/metrics/config.json";
          }
        ];
      }
    ];
    ruleFiles = [ rules/synapse-v2.rules ];
  };
}
