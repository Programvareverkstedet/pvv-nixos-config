{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "livekit";
    scheme = "https";
    metrics_path = "/prometheus-livekit/metrics";
    static_configs = [{
      targets = [ "matrix.pvv.ntnu.no" ];
    }];
  }];
}
