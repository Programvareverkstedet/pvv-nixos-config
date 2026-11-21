{ config, lib, pkgs, values, ... }: let
  cfg = config.services.grafana;
  grafanaMetricsPort = 9002;
in {
  imports = [
    ./alerts
    ./sirenhead
  ];

  sops.secrets = let
    owner = "grafana";
    group = "grafana";
    restartUnits = [ "grafana.service" ];
  in {
    "keys/grafana/secret_key" = { inherit owner group restartUnits; };
    "keys/grafana/admin_password" = { inherit owner group restartUnits; };
    "keys/grafana/renderer_token" = { inherit owner group restartUnits; };
  };

  sops.templates."grafana-image-renderer/environment" = {
    restartUnits = [ "grafana-image-renderer.service" ];
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
        cookie_samesite = "strict";
        secret_key = secretFile config.sops.secrets."keys/grafana/secret_key".path;
        admin_password = secretFile config.sops.secrets."keys/grafana/admin_password".path;
      };

      rendering = {
        server_url = "http://${config.services.grafana-image-renderer.settings.server.addr}/render";
        callback_url = "https://grafana.pvv.ntnu.no/";
        renderer_token = secretFile config.sops.secrets."keys/grafana/renderer_token".path;
      };

      dashboards = {
        default_home_dashboard_path = toString dashboards/home.json;
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
          jsonData.manageAlerts = false;
        }
        {
          name = "Ildkule loki";
          uid = "ildkule-loki";
          type = "loki";
          url = "http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}";
          # NOTE: it might be valuable turning this on again in the future if we need more efficient log alert queries,
          #       but for now it's neater to keep all alert logic in one place.
          jsonData.manageAlerts = false;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "Authentication";
          type = "file";
          options.path = dashboards/auth.json;
        }
        {
          name = "Node Exporter Full";
          type = "file";
          url = "https://grafana.com/api/dashboards/1860/revisions/46/download";
          options.path = dashboards/node-exporter-full.json;
        }
        {
          name = "Blackbox Exporter";
          type = "file";
          url = "https://grafana.com/api/dashboards/14928/revisions/6/download";

          # NOTE: see https://github.com/grafana/grafana/issues/10786
          # patched with
          #   sed 's/"\${DS_PROMETHEUS}"/{"type": "prometheus", "uid": "ildkule-prometheus"}/g'
          options.path = dashboards/blackbox.json;
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

  services.fluent-bit.settings = {
    parsers = [
      {
        name = "grafana_journal";
        format = "json";
      }
      {
        name = "grafana_image_renderer_logfmt";
        format = "logfmt";
      }
    ];

    pipeline.filters = lib.mkAfter (
      [
        # grafana
        {
          name = "parser";
          match = "journal.grafana.service";
          key_name = "message";
          parser = "grafana_journal";
          reserve_data = true;
        }

        # grafan-image-renderer
        {
          name = "modify";
          match = "journal.grafana-image-renderer.service";
          remove = [ "level" ];
        }
        {
          name = "parser";
          match = "journal.grafana-image-renderer.service";
          key_name = "message";
          parser = "grafana_image_renderer_logfmt";
          reserve_data = true;
        }
      ]
      ++ (lib.mapAttrsToList (k: v: {
        name = "modify";
        match = "journal.grafana-image-renderer.service";
        condition = "Key_value_equals level ${k}";
        set = "level ${v}";
      }) {
        ERROR = "error";
        WARN = "warning";
        INFO = "info";
        DEBUG = "debug";
      })
      ++ [
        {
          name = "modify";
          match = "journal.grafana-image-renderer.service";
          add = [ "level info" ];
        }
      ]
    );
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

  services.nginx.virtualHosts."grafana-metrics" = {
    listen = [ { addr = "127.0.0.1"; port = grafanaMetricsPort; } ];
    locations."= /metrics".proxyPass = "http://unix:${cfg.settings.server.socket}:";
    locations."/".return = "404";
  };

  services.prometheus.scrapeConfigs = [{
    job_name = "grafana";
    static_configs = [{
      targets = [ "127.0.0.1:${toString grafanaMetricsPort}" ];
    }];
  }];

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

      "= /metrics".return = "404";

      "/rss-proxy/ntnu-it-status" = {
        proxyPass = "https://status.it.ntnu.no/history.rss";
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_set_header Host status.it.ntnu.no;
        '';
      };
    };
  };
}
