{ config, lib, pkgs, values, ... }:
let
  cfg = config.services.prometheus.exporters.smartctl;
  socketPath = "/run/prometheus-smartctl-exporter.sock";
in
{
  services.prometheus.exporters.smartctl = {
    enable = lib.mkDefault config.services.smartd.enable;
    listenAddress = "127.0.0.1";
    port = 9633;
  };

  systemd.sockets.prometheus-smartctl-exporter = lib.mkIf cfg.enable {
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
    "prometheus-smartctl-exporter" = {
      unitConfig.ConditionVirtualization = "no";
      serviceConfig = {
        Slice = "system-monitoring.slice";
        ExecStart = let
          args = [
            "--web.systemd-socket"
            "--smartctl.interval=${cfg.maxInterval}"
          ]
          ++ map (device: "--smartctl.device=${device}") cfg.devices
          ++ cfg.extraFlags;
        in lib.mkForce "${pkgs.prometheus-smartctl-exporter}/bin/smartctl_exporter ${lib.escapeShellArgs args}";
      };
    };

    httpd = lib.mkIf (cfg.enable && config.services.httpd.enable) {
      after = [ "prometheus-smartctl-exporter.socket" ];
      wants = [ "prometheus-smartctl-exporter.socket" ];
      serviceConfig.BindPaths = [ "-${socketPath}" ];
    };
  };

  services.nginx = lib.mkIf cfg.enable {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-smartctl-exporter/metrics" = {
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
    virtualHosts.${config.networking.fqdn}.locations."/prometheus-smartctl-exporter/metrics" = {
      proxyPass = "unix:${socketPath}|http://localhost/metrics";

      extraConfig = ''
        Require ip 127.0.0.1
        Require ip ::1
        Require ip ${values.hosts.ildkule.ipv4}
        Require ip ${values.hosts.ildkule.ipv6}
      '';
    };
  };
}
