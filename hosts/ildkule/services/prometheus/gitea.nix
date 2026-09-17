{ ... }:
{
  services.prometheus.scrapeConfigs = [{
    job_name = "gitea";
    scheme = "https";

    static_configs = [
      {
        targets = [
          "git.pvv.ntnu.no:443"
        ];
      }
    ];
  }];
}
