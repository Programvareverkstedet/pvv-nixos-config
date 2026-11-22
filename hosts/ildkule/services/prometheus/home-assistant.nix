{ config, ... }:
{
  sops.secrets."keys/home-assistant/prometheus_token" = {
    owner = config.systemd.services.prometheus.serviceConfig.User;
  };

  services.prometheus.scrapeConfigs = [{
    job_name = "home-assistant";
    scheme = "https";
    metrics_path = "/api/prometheus";
    scrape_interval = "60s";
    authorization.credentials_file = config.sops.secrets."keys/home-assistant/prometheus_token".path;
    static_configs = [{
      targets = [ "homeassistant.pvv.ntnu.no:8123" ];
      labels.hostname = "homeassistant";
    }];
  }];
}
