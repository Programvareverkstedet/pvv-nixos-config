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
              "knakelibrak.pvv.ntnu.no:9100"
            ];
          }
        ];
      }
    ];
  };
}
