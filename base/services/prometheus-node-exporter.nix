{ config, lib, values, ... }:
let
  cfg = config.services.prometheus.exporters.node;
in
{
  services.prometheus.exporters.node = {
    enable = lib.mkDefault true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  services.nginx = lib.mkIf cfg.enable {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-node-exporter/metrics" = {
        proxyPass = "http://localhost:${toString cfg.port}/metrics";

        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      };
    };
  };

  systemd.services = lib.mkIf cfg.enable {
    "prometheus-node-exporter".serviceConfig.Slice = "system-monitoring.slice";
  };
}
