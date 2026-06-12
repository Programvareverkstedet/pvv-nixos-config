{ config, pkgs, ... }:

let
  cfg = config.services.loki;
  stateDir = "/data/monitoring/loki";
  # internalPort = 83100;
in {
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_port = 31832;
        http_listen_address = "127.0.0.1";
        grpc_listen_port = 9096;
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
        ];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "${stateDir}/boltdb-shipper-index";
          cache_location = "${stateDir}/boltdb-shipper-cache";
          cache_ttl = "24h";
        };
        filesystem = {
          directory = "${stateDir}/chunks";
        };
      };

      limits_config = {
        allow_structured_metadata = false;
        reject_old_samples = true;
        reject_old_samples_max_age = "72h";
      };

      compactor = {
        working_directory = "${stateDir}/compactor";
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

  services.nginx.virtualHosts."loki-internal" = {
    listen = [{
      addr = "0.0.0.0";
      port = 3100;
      ssl = false;
    }];
    locations = {
      "/loki/api/v1/push" = {
        proxyPass = "http://${cfg.configuration.server.http_listen_address}:${toString cfg.configuration.server.http_listen_port}";
      };
      "/" = {
        return = "403";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 3100 ];
}
