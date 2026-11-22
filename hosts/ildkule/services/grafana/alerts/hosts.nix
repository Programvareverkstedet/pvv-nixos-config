{ config, lib, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup excludeHosts nodeJobs icmpJobs hostDown;

  icmpDashboardUrl = lib.concatStrings [
    "https://grafana.pvv.ntnu.no/d/pS6ZuGV7z/prometheus-blackbox-exporter"
    "?var-target={{ $labels.hostname }}.pvv.ntnu.no"
    "&from=now-6h&to=now"
  ];

  nodeDashboardUrl = lib.concatStrings [
    "https://grafana.pvv.ntnu.no/d/rYdddlPWk/node-exporter-full"
    "?var-job={{ $labels.job }}"
    "&var-nodename={{ $labels.hostname }}"
    "&var-node={{ $labels.instance }}"
    "&from=now-6h&to=now"
  ];

  computeHosts = [
    "gluttony"
    "lupine-.+"
    "wenche"
  ];

  mkHostUnreachableAlert = version: mkPromAlert {
    uid = "host-ipv${toString version}-unreachable";
    title = "Host unreachable over IPv${toString version}";
    expr = ''
      probe_success{job="blackbox-icmp${toString version}"}
        unless on (hostname) (${hostDown})
    '';
    threshold = { type = "lt"; params = [ 1 ]; };
    subject = "{{ $labels.hostname }}";
    summary = let
      opp = if version == 4 then 6 else 4;
    in "Unpingable over IPv${toString version} for 5 minutes, still answers IPv${toString opp}.";
    dashboardUrl = icmpDashboardUrl;
  };
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "hosts" [
      (mkPromAlert {
        uid = "host-down";
        title = "Host down";
        expr = ''max by (hostname) (probe_success{${icmpJobs}})'';
        threshold = { type = "lt"; params = [ 1 ]; };
        severity = "critical";
        subject = "{{ $labels.hostname }}";
        summary = "Unpingable on both IPv4 and IPv6 for 5 minutes.";
        dashboardUrl = icmpDashboardUrl;
      })
      (mkHostUnreachableAlert 4)
      (mkHostUnreachableAlert 6)
      (mkPromAlert {
        uid = "host-high-cpu";
        title = "Host high CPU load";
        expr = let
          selector = excludeHosts computeHosts;
        in ''
          1 - (
            sum by (hostname, instance, job) (rate(node_cpu_seconds_total{mode=~"idle|iowait", ${selector}}[5m]))
            /
            count by (hostname, instance, job) (node_cpu_seconds_total{mode="idle", ${selector}})
          )
        '';
        threshold = { type = "gt"; params = [ 0.8 ]; };
        for = "10m";
        subject = "{{ $labels.hostname }}";
        summary = "Above 80% for 10 minutes.";
        dashboardUrl = nodeDashboardUrl;
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
        subject = "{{ $labels.device }} ({{ $labels.direction }}) on {{ $labels.hostname }}";
        summary = "Averaged above 80% of link capacity for an hour.";
        dashboardUrl = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "host-memory-high";
        title = "Host memory usage high";
        expr = ''
          1 - (
            node_memory_MemAvailable_bytes{${nodeJobs}, ${excludeHosts computeHosts}}
            /
            node_memory_MemTotal_bytes
          )
        '';
        threshold = { type = "gt"; params = [ 0.9 ]; };
        for = "15m";
        subject = "{{ $labels.hostname }}";
        summary = "Over 90% of memory in use for 15 minutes.";
        dashboardUrl = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "host-swap-high";
        title = "Host swap usage high";
        expr = ''
          1 - (
            node_memory_SwapFree_bytes{${nodeJobs}, ${excludeHosts computeHosts}}
            /
            (node_memory_SwapTotal_bytes > 0)
          )
        '';
        threshold = { type = "gt"; params = [ 0.9 ]; };
        for = "15m";
        subject = "{{ $labels.hostname }}";
        summary = "Over 90% of swap in use for 15 minutes.";
        dashboardUrl = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "disk-almost-full";
        title = "Disk almost full";
        expr = ''
          max by (hostname, device) (
            1 - (
              node_filesystem_avail_bytes{fstype=~"ext[234]|btrfs|vfat"}
              /
              node_filesystem_size_bytes
            )
          )
        '';
        threshold = { type = "gt"; params = [ 0.9 ]; };
        for = "15m";
        subject = "{{ $labels.device }} on {{ $labels.hostname }}";
        summary = "Over 90% full for 15 minutes.";
        dashboardUrl = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "disk-inodes-almost-exhausted";
        title = "Disk inodes almost exhausted";
        expr = ''
          max by (hostname, device) (
            1 - (
              node_filesystem_files_free{${nodeJobs}, fstype=~"ext[234]"}
              /
              node_filesystem_files
            )
          )
        '';
        threshold = { type = "gt"; params = [ 0.9 ]; };
        for = "15m";
        subject = "{{ $labels.device }} on {{ $labels.hostname }}";
        summary = "Over 90% of inodes in use for 15 minutes.";
        dashboardUrl = nodeDashboardUrl;
      })
    ])
  ];
}
