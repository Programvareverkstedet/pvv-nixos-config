{ config, ... }: let
  cfg = config.services.prometheus;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "git-gogs";
    scheme = "https";
    metrics_path = "/-/metrics";
    static_configs = [
      {
        targets = [
          "essendrop.pvv.ntnu.no:443"
        ];
      }
    ];
  }];
}
