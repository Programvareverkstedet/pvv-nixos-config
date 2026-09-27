{ config, lib, pkgs, values, ... }:
let
  cfg = config.services.prometheus.exporters.node;
  socketPath = "/run/prometheus-node-exporter.sock";
in
{
  services.prometheus.exporters.node = {
    enable = lib.mkDefault true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  # https://github.com/NixOS/nixpkgs/issues/510379
  systemd.sockets.prometheus-node-exporter = lib.mkIf cfg.enable {
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
    "prometheus-node-exporter" = {
      serviceConfig = {
        Slice = "system-monitoring.slice";
        ExecStart = let
          args = lib.cli.toCommandLineShellGNU { } (
               (lib.listToAttrs (map (x: lib.nameValuePair "collector.${x}" true) cfg.enabledCollectors))
            // (lib.listToAttrs (map (x: lib.nameValuePair "no-collector.${x}" true) cfg.disabledCollectors))
            // { "web.systemd-socket" = true; }
          );
        in lib.mkForce "${pkgs.prometheus-node-exporter}/bin/node_exporter ${args} ${lib.escapeShellArgs cfg.extraFlags}";
      };
    };

    httpd = lib.mkIf (cfg.enable && config.services.httpd.enable) {
      after = [ "prometheus-node-exporter.socket" ];
      wants = [ "prometheus-node-exporter.socket" ];
      serviceConfig.BindPaths = [ "-${socketPath}" ];
    };
  };

  services.nginx = lib.mkIf cfg.enable {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-node-exporter/metrics" = {
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
    virtualHosts.${config.networking.fqdn}.locations."/prometheus-node-exporter/metrics" = {
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
        name = "node_exporter_logfmt";
        format = "logfmt";
      }
    ];

    pipeline.filters = lib.mkAfter (
      [
        {
          name = "modify";
          match = "journal.prometheus-node-exporter.service";
          remove = [ "level" ];
        }
        {
          name = "parser";
          match = "journal.prometheus-node-exporter.service";
          key_name = "message";
          parser = "node_exporter_logfmt";
          reserve_data = true;
        }
      ]
      ++ (lib.mapAttrsToList (k: v: {
        name = "modify";
        match = "journal.prometheus-node-exporter.service";
        condition = "Key_value_equals level ${k}";
        set = "level ${v}";
      }) {
        ERROR = "error";
        WARN = "warning";
        INFO = "info";
        DEBUG = "debug";
      })
      ++ [
        {
          name = "modify";
          match = "journal.prometheus-node-exporter.service";
          add = [ "level info" ];
        }
      ]
    );
  };
}
