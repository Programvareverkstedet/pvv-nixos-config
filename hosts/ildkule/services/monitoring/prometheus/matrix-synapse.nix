{ ... }:
{
  services.prometheus.scrapeConfigs = [
    {
      job_name = "synapse";
      scrape_interval = "15s";
      scheme = "https";

      http_sd_configs = [
        {
          url = "https://matrix.pvv.ntnu.no/metrics/config.json";
        }
      ];

      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          regex = "[^/]+(/.*)";
          target_label = "__metrics_path__";
        }
        {
          source_labels = [ "__address__" ];
          regex = "([^/]+)/.*";
          target_label = "instance";
        }
        {
          source_labels = [ "__address__" ];
          regex = "[^/]+\\/+[^/]+/(.*)/\\d+$";
          target_label = "job";
        }
        {
          source_labels = [ "__address__" ];
          regex = "[^/]+\\/+[^/]+/.*/(\\d+)$";
          target_label = "index";
        }
        {
          source_labels = [ "__address__" ];
          regex = "([^/]+)/.*";
          target_label = "__address__";
        }
      ];
    }
  ];
}
