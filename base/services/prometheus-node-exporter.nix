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
      SocketGroup = config.services.nginx.group;
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
}
