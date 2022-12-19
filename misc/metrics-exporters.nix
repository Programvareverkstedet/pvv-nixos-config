{ config, pkgs, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 28183;
        grpc_listen_port = 0;
      };
      positions = {
        filename = "/var/lib/promtail/positions.yaml";
      };
      clients = [
        {
          url = "http://ildkule.pvv.ntnu.no:3100/loki/api/v1/push";
        }
      ];
      scrape_configs = [
        {
          job_name = "systemd-journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
          ];
        }
      ];
    };
  };

}
