{ config, lib, pkgs, values, ... }:
let
  cfg = config.services.prometheus.exporters.systemd;
  socketPath = "/run/prometheus-systemd-exporter.sock";
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

  systemd.sockets.prometheus-systemd-exporter = lib.mkIf cfg.enable {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = socketPath;
      SocketGroup = config.services.nginx.group;
      SocketMode = "0660";
    };
  };

  systemd.services = lib.mkIf cfg.enable {
    "prometheus-systemd-exporter" = {
      serviceConfig = {
        Slice = "system-monitoring.slice";
        ExecStart = lib.mkForce "${pkgs.prometheus-systemd-exporter}/bin/systemd_exporter --web.systemd-socket ${lib.escapeShellArgs cfg.extraFlags}";
      };
    };
  };

  services.nginx = lib.mkIf cfg.enable {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-systemd-exporter/metrics" = {
        proxyPass = "http://unix:${socketPath}:/metrics";

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
