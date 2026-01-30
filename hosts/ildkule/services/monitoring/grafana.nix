{ config, pkgs, values, ... }: let
  cfg = config.services.grafana;
in {
  sops.secrets = let
    owner = "grafana";
    group = "grafana";
  in {
    "keys/grafana/secret_key" = { inherit owner group; };
    "keys/grafana/admin_password" = { inherit owner group; };
  };

  services.grafana = {
    enable = true;

    settings = let
      # See https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#file-provider
      secretFile = path: "$__file{${path}}";
    in {
      server = {
        domain = "grafana.pvv.ntnu.no";
        http_port = 2342;
        http_addr = "127.0.0.1";
      };

      security = {
        secret_key = secretFile config.sops.secrets."keys/grafana/secret_key".path;
        admin_password = secretFile config.sops.secrets."keys/grafana/admin_password".path;
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Ildkule Prometheus";
          type = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
        }
        {
          name = "Ildkule loki";
          type = "loki";
          url = "http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}";
        }
      ];
      dashboards.settings.providers = [
        {
          name = "Node Exporter Full";
          type = "file";
          url = "https://grafana.com/api/dashboards/1860/revisions/42/download";
          options.path = dashboards/node-exporter-full.json;
        }
        {
          name = "Matrix Synapse";
          type = "file";
          url = "https://github.com/element-hq/synapse/raw/refs/heads/develop/contrib/grafana/synapse.json";
          options.path = dashboards/synapse.json;
        }
        {
          name = "MySQL";
          type = "file";
          url = "https://raw.githubusercontent.com/prometheus/mysqld_exporter/main/mysqld-mixin/dashboards/mysql-overview.json";
          options.path = dashboards/mysql.json;
        }
        {
          name = "Postgresql";
          type = "file";
          url = "https://grafana.com/api/dashboards/9628/revisions/8/download";
          options.path = dashboards/postgres.json;
        }
        {
          name = "Gitea Dashboard";
          type = "file";
          url = "https://grafana.com/api/dashboards/17802/revisions/3/download";
          options.path = dashboards/gitea-dashboard.json;
        }
      ];

    };
  };

  services.nginx.virtualHosts.${cfg.settings.server.domain} = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.server.http_port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffers 8 1024k;
          proxy_buffer_size 1024k;
        '';
      };
    };
  };
}
