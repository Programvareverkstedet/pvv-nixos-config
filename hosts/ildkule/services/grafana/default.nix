{ config, lib, pkgs, values, ... }: let
  cfg = config.services.grafana;
in {
  sops.secrets = let
    owner = "grafana";
    group = "grafana";
  in {
    "keys/grafana/secret_key" = { inherit owner group; };
    "keys/grafana/admin_password" = { inherit owner group; };
    "keys/grafana/renderer_token" = { inherit owner group; };
  };

  sops.templates."grafana-image-renderer/environment" = {
    content = ''
      AUTH_TOKEN=${config.sops.placeholder."keys/grafana/renderer_token"}
    '';
  };

  services.grafana = {
    enable = true;

    settings = let
      # See https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#file-provider
      secretFile = path: "$__file{${path}}";
    in {
      server = {
        domain = "grafana.pvv.ntnu.no";
        root_url = "https://grafana.pvv.ntnu.no/";

        protocol = "socket";
        socket = "/run/grafana/grafana.sock";
        socket_mode = "0660";

        enable_gzip = false;
      };

      log = {
        mode = "syslog";
        filters = "bleve-backend:warn";
      };

      "log.syslog" = {
        format = "json";
        tag = "grafana";
      };

      security = {
        disable_gravatar = true;
        cookie_secure = true;
        secret_key = secretFile config.sops.secrets."keys/grafana/secret_key".path;
        admin_password = secretFile config.sops.secrets."keys/grafana/admin_password".path;
      };

      rendering = {
        server_url = "http://${config.services.grafana-image-renderer.settings.server.addr}/render";
        callback_url = "https://grafana.pvv.ntnu.no/";
        renderer_token = secretFile config.sops.secrets."keys/grafana/renderer_token".path;
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Ildkule Prometheus";
          uid = "ildkule-prometheus";
          type = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
        }
        {
          name = "Ildkule loki";
          uid = "ildkule-loki";
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
        {
          name = "Matrix OOYE";
          type = "file";
          options.path = dashboards/matrix-ooye.json;
        }
        {
          name = "Dibbler";
          type = "file";
          options.path = dashboards/dibbler.json;
        }
      ];
    };
  };

  systemd.services.grafana = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  services.grafana-image-renderer = {
    enable = true;
  };

  systemd.services.grafana-image-renderer = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    serviceConfig.EnvironmentFile = config.sops.templates."grafana-image-renderer/environment".path;
  };

  systemd.services.nginx.serviceConfig.SupplementaryGroups = [ "grafana" ];

  services.nginx.virtualHosts.${cfg.settings.server.domain} = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations = {
      "/" = {
        proxyPass = "http://unix:${cfg.settings.server.socket}:";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffers 8 1024k;
          proxy_buffer_size 1024k;
        '';
      };
    };
  };
}
