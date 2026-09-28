{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "mjolnir";
    scheme = "https";
    metrics_path = "/prometheus-mjolnir/metrics";
    static_configs = [{
      targets = [ "matrix.pvv.ntnu.no" ];
    }];
  }];
}
