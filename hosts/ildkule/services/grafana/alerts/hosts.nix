{ config, lib, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup excludeHosts;

  nodeDashboardUrl = lib.concatStrings [
    "https://grafana.pvv.ntnu.no/d/rYdddlPWk/node-exporter-full"
    "?var-job={{ $labels.job }}"
    "&var-nodename={{ $labels.hostname }}"
    "&var-node={{ $labels.instance }}"
    "&from=now-6h&to=now"
  ];
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "hosts" [
      (mkPromAlert {
        uid = "host-down";
        title = "Host down";
        expr = ''up{job=~"nixos-node|non-nixos-node"}'';
        threshold = { type = "lt"; params = [ 1 ]; };
        severity = "critical";
        summary = "{{ $labels.hostname }} is down";
        description = "node-exporter on {{ $labels.instance }} has not been scrapable for 5 minutes.";
        annotations.dashboard_url = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "host-high-cpu";
        title = "Host high CPU load";
        expr = let
          ignoreHosts = [
            "gluttony"
            "lupine-1"
            "lupine-2"
            "lupine-3"
            "lupine-4"
            "lupine-5"
            "wenche"
          ];
          selector = excludeHosts ignoreHosts;
        in ''
          1 - (
            sum by (hostname, instance, job) (rate(node_cpu_seconds_total{mode=~"idle|iowait", ${selector}}[5m]))
            /
            count by (hostname, instance, job) (node_cpu_seconds_total{mode="idle", ${selector}})
          )
        '';
        threshold = { type = "gt"; params = [ 0.8 ]; };
        for = "10m";
        summary = "{{ $labels.hostname }} CPU load is {{ humanizePercentage $values.A.Value }}";
        description = "CPU load on {{ $labels.hostname }} has been above 80% for 10 minutes.";
        annotations.dashboard_url = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "host-network-saturated";
        title = "Host network saturated";
        expr = let
          ignoreHosts = [
            "gluttony"
            "wenche"
          ];
          capacityBytes = "125e6"; # 1 Gbit/s
          rate = metric: ''
            sum by (hostname, instance, job, device) (
              rate(${metric}{device=~"en.*|eth.*", ${excludeHosts ignoreHosts}}[30m])
            ) / ${capacityBytes}
          '';
        in ''
          label_replace(${rate "node_network_receive_bytes_total"}, "direction", "rx", "", "")
          or
          label_replace(${rate "node_network_transmit_bytes_total"}, "direction", "tx", "", "")
        '';
        threshold = { type = "gt"; params = [ 0.8 ]; };
        for = "30m";
        summary = "Network saturated on {{ $labels.hostname }}[{{ $labels.direction }}]: {{ humanizePercentage $values.A.Value }} of 1 Gbit/s";
        description = "Avg {{ $labels.direction }} {{ $labels.device }} has been above 80% of link capacity for an hour.";
        annotations.dashboard_url = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "disk-almost-full";
        title = "Disk almost full";
        expr = ''
          max by (hostname, device) (
            1 - node_filesystem_avail_bytes{fstype=~"ext[234]|btrfs|vfat"}
              / node_filesystem_size_bytes
          )
        '';
        threshold = { type = "gt"; params = [ 0.9 ]; };
        for = "15m";
        summary = "{{ $labels.device }} on {{ $labels.hostname }} is {{ humanizePercentage $values.A.Value }} full";
      })
    ])
  ];
}
