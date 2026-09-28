{ config, ... }: let
  lokiCfg = config.services.loki.configuration.server;
in {
  services.prometheus.scrapeConfigs = [{
    job_name = "loki";
    static_configs = [{
      targets = [ "${lokiCfg.http_listen_address}:${toString lokiCfg.http_listen_port}" ];
    }];
  }];
}
