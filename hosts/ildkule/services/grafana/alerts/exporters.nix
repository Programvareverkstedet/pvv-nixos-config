{ config, lib, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup hostDown;

  hostJobNames = {
    node-exporter = [ "nixos-node" "non-nixos-node" ];
    systemd-exporter = [ "nixos-systemd" ];
    smartctl-exporter = [ "nixos-smartctl" ];
    fluent-bit = [ "nixos-fluent-bit" ];
    flake-input-exporter = [ "nixos-flake-input" ];
  };

  serviceExporters = lib.genAttrs [
    "exim"
    "gatus"
    "gitea"
    "gitea-runner"
    "grafana"
    "livekit"
    "loki"
    "matrix-ooye"
    "mjolnir"
    "mysql"
    "phpfpm"
    "postgres"
    "prometheus"
  ] (job: ''job="${job}"'') // {
    synapse = ''index!=""'';
    sql = ''job="sql_exporter"'';
  };

  # This creates an alert for a single exporter. If the whole host is down,
  # host-down reports it instead.
  mkExporterDownAlert = name: jobs: mkPromAlert {
    uid = "host-${name}-down";
    title = "${name} down";
    expr = ''
      up{job=~"${lib.concatStringsSep "|" jobs}"}
        unless on (hostname) (${hostDown})
    '';
    threshold = { type = "lt"; params = [ 1 ]; };
    noDataState = "OK";
    summary = "${name} on {{ $labels.hostname }} is down";
    description = "{{ $labels.instance }} ({{ $labels.job }}) unreachable for 5 minutes.";
  };

  mkServiceExporterDownAlert = name: selector: mkPromAlert {
    uid = "service-${name}-exporter-down";
    title = "${name} exporter down";
    expr = ''
      up{${selector}}
        unless on (hostname) (${hostDown})
    '';
    threshold = { type = "lt"; params = [ 1 ]; };
    noDataState = "OK";
    summary = "${name} exporter at {{ $labels.instance }} is down";
    description = "{{ $labels.instance }} ({{ $labels.job }}) unreachable for 5 minutes.";
  };
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "exporters" (
         lib.mapAttrsToList mkExporterDownAlert hostJobNames
      ++ lib.mapAttrsToList mkServiceExporterDownAlert serviceExporters
      ++ [
        (mkPromAlert {
          uid = "blackbox-exporter-down";
          title = "Blackbox exporter down";
          expr = ''max(up{job=~"blackbox-.*"})'';
          threshold = { type = "lt"; params = [ 1 ]; };
          noDataState = "OK";
          summary = "Blackbox exporter is down";
          description = "All blackbox probes unreachable for 5 minutes.";
        })
      ]
    ))
  ];
}
