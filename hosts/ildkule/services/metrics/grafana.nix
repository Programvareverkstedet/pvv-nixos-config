{ config, pkgs, ... }:

{
  services.grafana = {
    enable = true;
    settings.server = {
      domain = "ildkule.pvv.ntnu.no";
      http_port = 2342;
      http_addr = "127.0.0.1";
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Ildkule Prometheus";
          type = "prometheus";
          url = ("http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}");
         isDefault = true;
        }
      ];
    };
  };

  services.nginx.virtualHosts.${config.services.grafana.domain} = {
    locations = {
      "/" = {
        proxyPass = "http://${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffers 8 1024k;
          proxy_buffer_size 1024k;
          proxy_set_header Host $host;
        '';
      };
    };
  };
}
