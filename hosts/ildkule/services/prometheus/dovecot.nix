{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "dovecot";
    scheme = "https";

    static_configs = [{
      targets = [ "microbel.pvv.ntnu.no:9900" ];
    }];
  }];
}
