{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "matrix-ooye";
    scheme = "https";
    static_configs = [{
      targets = [ "ooye.pvv.ntnu.no" ];
    }];
  }];
}
