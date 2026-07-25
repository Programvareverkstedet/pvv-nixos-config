{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "phpfpm";
    scheme = "https";
    metrics_path = "/prometheus-php-fpm-exporter/metrics";

    static_configs = [
      {
        labels.hostname = "bekkalokk";
        targets = [ "www.pvv.ntnu.no:443" ];
      }
    ];
  }];
}
