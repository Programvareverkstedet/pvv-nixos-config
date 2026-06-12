{ config, lib, values, ... }:
let
  cfg = config.services.prometheus.exporters.systemd;
in
{
  services.prometheus.exporters.systemd = {
    enable = lib.mkDefault true;
    listenAddress = "127.0.0.1";
    port = 9101;
    extraFlags = [
      "--systemd.collector.enable-restart-count"
      "--systemd.collector.enable-ip-accounting"
    ];
  };

  services.nginx = {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-systemd-exporter/metrics" = {
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
}
