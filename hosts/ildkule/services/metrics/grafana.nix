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
        {
          name = "Ildkule loki";
          type = "loki";
          url = ("http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}");
        }
      ];
      dashboards.settings.providers = [
        {
          name = "Node Exporter Full";
          type = "file";
          url = "https://grafana.com/api/dashboards/1860/revisions/29/download";
          options.path = dashboards/node-exporter-full.json;
        }
      ];

    };
  };

  services.nginx.virtualHosts.${config.services.grafana.settings.server.domain} = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffers 8 1024k;
          proxy_buffer_size 1024k;
        '';
      };
    };
  };
}
