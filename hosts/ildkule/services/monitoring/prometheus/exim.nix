{ ... }:
{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "exim";
        scrape_interval = "15s";
        static_configs = [{
          targets = [ "microbel.pvv.ntnu.no:9636" ];
        }];
      }
    ];
  };
}
