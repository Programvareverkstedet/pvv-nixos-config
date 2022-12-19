{ config, pkgs, ... }:

{
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_port = 3100;
        grpc_listen_port = 9096;
      };

      ingester = {
        wal = {
          enabled = true;
          dir = "/var/lib/loki/wal";
        };
        lifecycler = {
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "10m";
      };

      schema_config = {
        configs = [
          {
            from = "2022-01-01";
            store = "boltdb";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "48h";
            };
          }
        ];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/index";
          shared_store = "filesystem";
          cache_ttl = "24h";
        };
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        enforce_metric_name = false;
        reject_old_samples = true;
        reject_old_samples_max_age = "72h";
      };

      compactor = {
        working_directory = "/var/lib/loki/compactor";
        shared_store = "filesystem";
      };

      # ruler = {
      #   storage = {
      #     type = "local";
      #     local = {
      #       directory = "/var/lib/loki/rules";
      #     };
      #   };
      #   rule_path = "/etc/loki/rules";
      #   alertmanager_url = "http://localhost:9093";
      # };
    };
  };
}
