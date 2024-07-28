{ config, pkgs, values, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  systemd.services.prometheus-node-exporter.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      "127.0.0.1"
      "::1"
      values.hosts.ildkule.ipv4
      values.hosts.ildkule.ipv6
    ];
  };


  services.prometheus.exporters.systemd = {
    enable = true;
    port = 9101;
    extraFlags = [
      "--systemd.collector.enable-restart-count"
      "--systemd.collector.enable-ip-accounting"
    ];
  };

  systemd.services.prometheus-systemd-exporter.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      "127.0.0.1"
      "::1"
      values.hosts.ildkule.ipv4
      values.hosts.ildkule.ipv6
      values.hosts.ildkule.ipv4_global
      values.hosts.ildkule.ipv6_global
    ];
  };
  

  networking.firewall.allowedTCPPorts = [ 9100 9101 ];

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 28183;
        grpc_listen_port = 0;
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
            {
              source_labels = [ "__journal_priority_keyword" ];
              target_label = "level";
            }
          ];
        }
      ];
    };
  };

}
