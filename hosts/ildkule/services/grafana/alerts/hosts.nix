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

  ipv4OnlyIcmpHosts = [
    # No AAAA record
    "balduzius"
    "dvask"
    "knutsen"
    "ludvigsen"

    # Broken IPv6 for unknown reasons
    "ambidextrous"
    "buskerud"
    "kana"
  ];

  mkHostUnreachableAlert = version: mkPromAlert {
    uid = "host-ipv${toString version}-unreachable";
    title = "Host unreachable over IPv${toString version}";
    expr = let
      selector = lib.optionalString (version == 6) ", ${excludeHosts ipv4OnlyIcmpHosts}";
    in ''
      probe_success{job="blackbox-icmp${toString version}"${selector}}
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

      (let
        expr = ''
          max by (hostname, device) (
            1 - (
              node_filesystem_avail_bytes{fstype=~"ext[234]|btrfs|vfat"}
              /
              node_filesystem_size_bytes
            )
          )
        '';
      in [
        (mkPromAlert {
          uid = "disk-almost-full";
          title = "Disk almost full";
          inherit expr;
          threshold = { type = "gt"; params = [ 0.9 ]; };
          for = "15m";
          subject = "{{ $labels.device }} on {{ $labels.hostname }}";
          summary = "Over 90% full for 15 minutes.";
          dashboardUrl = nodeDashboardUrl;
        })

        (mkPromAlert {
          uid = "disk-full";
          title = "Disk full";
          inherit expr;
          threshold = { type = "gt"; params = [ 0.99 ]; };
          severity = "critical";
          subject = "{{ $labels.device }} on {{ $labels.hostname }}";
          summary = "Over 99% full for 5 minutes.";
          dashboardUrl = nodeDashboardUrl;
        })
      ])

      (let
        expr = ''
          max by (hostname, device) (
            1 - (
              node_filesystem_files_free{${nodeJobs}, fstype=~"ext[234]"}
              /
              node_filesystem_files
            )
          )
        '';
      in [
        (mkPromAlert {
          uid = "disk-inodes-almost-exhausted";
          title = "Disk inodes almost exhausted";
          inherit expr;
          threshold = { type = "gt"; params = [ 0.9 ]; };
          for = "15m";
          subject = "{{ $labels.device }} on {{ $labels.hostname }}";
          summary = "Over 90% of inodes in use for 15 minutes.";
          dashboardUrl = nodeDashboardUrl;
        })

        (mkPromAlert {
          uid = "disk-inodes-exhausted";
          title = "Disk inodes exhausted";
          inherit expr;
          threshold = { type = "gt"; params = [ 0.99 ]; };
          severity = "critical";
          subject = "{{ $labels.device }} on {{ $labels.hostname }}";
          summary = "Over 99% of inodes in use for 5 minutes.";
          dashboardUrl = nodeDashboardUrl;
        })
      ])

      (mkPromAlert {
        uid = "host-nfs-mount-broken";
        title = "NFS mount broken";
        expr = ''
          count by (hostname, instance, job, device_error) (
            node_filesystem_device_error{${nodeJobs}, fstype=~"nfs.*"} == 1
          )
        '';
        threshold = { type = "gt"; params = [ 0 ]; };
        for = "15m";
        severity = "critical";
        subject = "{{ $labels.hostname }} ({{ $labels.device_error }})";
        summary = "NFS mounts have been erroring for 15 minutes.";
        dashboardUrl = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "host-conntrack-high";
        title = "Host conntrack table filling up";
        expr = ''
          node_nf_conntrack_entries{${nodeJobs}}
          /
          node_nf_conntrack_entries_limit
        '';
        threshold = { type = "gt"; params = [ 0.8 ]; };
        for = "10m";
        subject = "{{ $labels.hostname }}";
        summary = "Conntrack table over 80% full for 10 minutes.";
        dashboardUrl = nodeDashboardUrl;
      })

      (mkPromAlert {
        uid = "host-conntrack-full";
        title = "Host conntrack table full";
        expr = ''
          sum by (hostname, instance, job) (
              increase(node_nf_conntrack_stat_early_drop{${nodeJobs}}[10m])
            + increase(node_nf_conntrack_stat_drop{${nodeJobs}}[10m])
            - increase(node_nf_conntrack_stat_insert_failed{${nodeJobs}}[10m])
          )
        '';
        threshold = { type = "gt"; params = [ 0 ]; };
        for = "0s";
        subject = "{{ $labels.hostname }}";
        summary = "Conntrack table full, connections are being dropped.";
        dashboardUrl = nodeDashboardUrl;
      })
    ])
  ];
}
