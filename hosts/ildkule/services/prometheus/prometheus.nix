{ config, ... }: let
  cfg = config.services.prometheus;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "prometheus";
    static_configs = [{
      targets = [ "${cfg.listenAddress}:${toString cfg.port}" ];
    }];
  }];
}
