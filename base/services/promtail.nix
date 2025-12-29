{ config, lib, values, ... }:
let
  cfg = config.services.prometheus.exporters.node;
in
{
  services.promtail = {
    enable = lib.mkDefault true;
    configuration = {
      server = {
        http_listen_port = 28183;
        grpc_listen_port = 0;
      };
      clients = [{
        url = "http://ildkule.pvv.ntnu.no:3100/loki/api/v1/push";
      }];
      scrape_configs = [{
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
          {
            source_labels = [ "__journal_priority_keyword" ];
            target_label = "level";
          }
        ];
      }];
    };
  };
}
