{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "gitea-runner";
    scheme = "https";
    metrics_path = "/gitea-runner/metrics";

    static_configs = map (name: {
      labels.hostname = name;
      targets = [ "${name}.pvv.ntnu.no:443" ];
    }) [
      "lupine-1"
      "lupine-2"
      "lupine-3"
      "lupine-4"
      "lupine-5"
    ];
  }];
}
