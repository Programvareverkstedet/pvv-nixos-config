{ config, ... }: let
  cfg = config.services.prometheus;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "base_info";
    static_configs = [
      { labels.hostname = "ildkule";
        targets = [
          "ildkule.pvv.ntnu.no:${toString cfg.exporters.node.port}"
          "ildkule.pvv.ntnu.no:${toString cfg.exporters.systemd.port}"
        ];
      }
      { labels.hostname = "bekkalokk";
        targets = [
          "bekkalokk.pvv.ntnu.no:9100"
          "bekkalokk.pvv.ntnu.no:9101"
        ];
      }
      { labels.hostname = "kommode";
        targets = [
          "kommode.pvv.ntnu.no:9100"
          "kommode.pvv.ntnu.no:9101"
        ];
      }
      { labels.hostname = "bicep";
        targets = [
          "bicep.pvv.ntnu.no:9100"
          "bicep.pvv.ntnu.no:9101"
        ];
      }
      { labels.hostname = "brzeczyszczykiewicz";
        targets = [
          "brzeczyszczykiewicz.pvv.ntnu.no:9100"
          "brzeczyszczykiewicz.pvv.ntnu.no:9101"
        ];
      }
      { labels.hostname = "georg";
        targets = [
          "georg.pvv.ntnu.no:9100"
          "georg.pvv.ntnu.no:9101"
        ];
      }
      { labels.hostname = "ustetind";
        targets = [
          "ustetind.pvv.ntnu.no:9100"
          "ustetind.pvv.ntnu.no:9101"
        ];
      }
      { labels.hostname =  "hildring";
        targets = [
          "hildring.pvv.ntnu.no:9100"
        ];
      }
      { labels.hostname =  "isvegg";
        targets = [
          "isvegg.pvv.ntnu.no:9100"
        ];
      }
      { labels.hostname =  "microbel";
        targets = [
          "microbel.pvv.ntnu.no:9100"
        ];
      }
    ];
  }];
}
