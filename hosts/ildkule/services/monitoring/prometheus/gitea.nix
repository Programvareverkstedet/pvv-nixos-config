{ ... }:
{
  services.prometheus.scrapeConfigs = [
    {
      job_name = "gitea";
      scrape_interval = "60s";
      scheme = "https";

      static_configs = [
        {
          targets = [
            "git.pvv.ntnu.no:443"
          ];
        }
      ];
    }
  ];
}
