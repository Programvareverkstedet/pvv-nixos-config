{ config, lib, pkgs, values, ... }:

let
  cfg = config.services.loki;
  stateDir = "/data/monitoring/loki";
in {
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_port = 31832;
        http_listen_address = "127.0.0.1";
        grpc_listen_port = 9096;
        log_format = "json";
      };

      ingester = {
        wal = {
          enabled = true;
          dir = "${stateDir}/wal";
        };
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "1h";
      };

      schema_config = {
        configs = [
          # TODO: drop after start of november 2026,
          #       roughly when the last boltdb data will
          #       have been deleted by retention date.
          {
            from = "2022-12-01";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
          {
            from = "2026-09-19";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "tsdb_index_";
              period = "24h";
            };
          }
        ];
      };

      storage_config = {
        # TODO: drop after start of november 2026,
        #       roughly when the last boltdb data will
        #       have been deleted by retention date.
        boltdb_shipper = {
          active_index_directory = "${stateDir}/boltdb-shipper-index";
          cache_location = "${stateDir}/boltdb-shipper-cache";
          cache_ttl = "24h";
        };
        tsdb_shipper = {
          active_index_directory = "${stateDir}/tsdb-index";
          cache_location = "${stateDir}/tsdb-cache";
          cache_ttl = "24h";
        };
        filesystem = {
          directory = "${stateDir}/chunks";
        };
      };

      query_range = {
        cache_results = true;
        results_cache.cache.embedded_cache = {
          enabled = true;
          max_size_mb = 1024;
        };
      };

      limits_config = {
        allow_structured_metadata = true;

        discover_service_name = [
          "syslog_identifier"
          "service_name"
          "service"
          "app"
          "application"
          "name"
          "app_kubernetes_io_name"
          "container"
          "container_name"
          "component"
          "workload"
          "job"
        ];

        reject_old_samples = true;
        reject_old_samples_max_age = "72h";

        ingestion_rate_mb = 32;
        ingestion_burst_size_mb = 64;
        per_stream_rate_limit = "32MB";
        per_stream_rate_limit_burst = "64MB";

        retention_period = "${toString (40 * 24)}h";
      };

      compactor = {
        working_directory = "${stateDir}/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };

      # ruler = {
      #   storage = {
      #     type = "local";
      #     local = {
      #       directory = "${stateDir}/rules";
      #     };
      #   };
      #   rule_path = "/etc/loki/rules";
      #   alertmanager_url = "http://localhost:9093";
      # };
    };
  };

  services.nginx.virtualHosts."loki.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;

    locations = {
      "/".return = "403";
      "/loki/api/v1/push" = {
        proxyPass = "http://${cfg.configuration.server.http_listen_address}:${toString cfg.configuration.server.http_listen_port}/loki/api/v1/push";
        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.ipv4-space};
          allow ${values.ipv6-space};
          allow ${values.ntnu.ipv4-space};
          allow ${values.ntnu.ipv6-space};
          deny all;
        '';
      };
      "/ready" = {
        proxyPass = "http://${cfg.configuration.server.http_listen_address}:${toString cfg.configuration.server.http_listen_port}/ready";
        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.ipv4-space};
          allow ${values.ipv6-space};
          allow ${values.ntnu.ipv4-space};
          allow ${values.ntnu.ipv6-space};
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      };
    };
  };
}
