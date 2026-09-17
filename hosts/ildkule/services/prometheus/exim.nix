{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "exim";
    scheme = "http";

    static_configs = [{
      targets = [ "microbel.pvv.ntnu.no:9636" ];
    }];
  }];
}
