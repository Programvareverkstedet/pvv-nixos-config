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
      SocketGroup = if config.services.nginx.enable then config.services.nginx.group else
                    if config.services.httpd.enable then config.services.httpd.group else
                    "nobody";
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

    httpd = lib.mkIf (cfg.enable && config.services.httpd.enable) {
      after = [ "prometheus-systemd-exporter.socket" ];
      wants = [ "prometheus-systemd-exporter.socket" ];
      serviceConfig.BindPaths = [ "-${socketPath}" ];
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

  services.httpd = lib.mkIf (cfg.enable && config.services.httpd.enable) {
    virtualHosts.${config.networking.fqdn}.locations."/prometheus-systemd-exporter/metrics" = {
      proxyPass = "unix:${socketPath}|http://localhost/metrics";

      extraConfig = ''
        Require ip 127.0.0.1
        Require ip ::1
        Require ip ${values.hosts.ildkule.ipv4}
        Require ip ${values.hosts.ildkule.ipv6}
      '';
    };
  };

  services.fluent-bit.settings = lib.mkIf cfg.enable {
    parsers = [
      {
        name = "systemd_exporter_logfmt";
        format = "logfmt";
      }
    ];

    pipeline.filters = lib.mkAfter [
      {
        name = "parser";
        match = "journal.prometheus-systemd-exporter.service";
        key_name = "message";
        parser = "systemd_exporter_logfmt";
        reserve_data = true;
      }
    ];
  };
}
