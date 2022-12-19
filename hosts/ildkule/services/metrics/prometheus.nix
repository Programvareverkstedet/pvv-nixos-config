{ config, pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9001;

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [
              "ildkule.pvv.ntnu.no:${toString config.services.prometheus.exporters.node.port}"
              "microbel.pvv.ntnu.no:9100"
              "knakelibrak.pvv.ntnu.no:9100"
            ];
          }
        ];
      }
    ];
  };
}
