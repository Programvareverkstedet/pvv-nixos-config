{ lib, ... }:
# NOTE: go check these resources:
# - https://samber.github.io/awesome-prometheus-alerts
# - https://github.com/search?q=lang%3Anix+provision.alerting&type=code
# - https://grafana.com/docs/grafana/latest/alerting/
let
  mkAlert = {
    uid,
    title,
    expr,
    datasourceUid,
    instantQuery,
    threshold ? { type = "gt"; params = [ 0 ]; },
    for ? "5m",
    severity ? "warning",
    summary,
    description ? null,
    noDataState ? "NoData",
    annotations ? { },
  }: {
    inherit uid title for noDataState;
    condition = "B";
    execErrState = "Error";
    labels = { inherit severity; };
    annotations = { inherit summary; }
      // lib.optionalAttrs (description != null) { inherit description; }
      // annotations;
    data = [
      {
        refId = "A";
        inherit datasourceUid;
        relativeTimeRange = { from = 300; to = 0; };
        model = {
          refId = "A";
          inherit expr;
        } // instantQuery;
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        model = {
          refId = "B";
          type = "threshold";
          expression = "A";
          conditions = [ { evaluator = threshold; } ];
        };
      }
    ];
  };

  mkPromAlert = args: mkAlert ({
    datasourceUid = "ildkule-prometheus";
    instantQuery.instant = true;
  } // args);

  mkLokiAlert = args: mkAlert ({
    datasourceUid = "ildkule-loki";
    instantQuery.queryType = "instant";
  } // args);

  mkGroup = name: rules: {
    orgId = 1;
    inherit name rules;
    folder = "Infrastructure";
    interval = "1m";
  };

  nodeDashboardUrl = lib.concatStrings [
    "https://grafana.pvv.ntnu.no/d/rYdddlPWk/node-exporter-full"
    "?var-job={{ $labels.job }}"
    "&var-nodename={{ $labels.hostname }}"
    "&var-node={{ $labels.instance }}"
    "&from=now-6h&to=now"
  ];

  excludeHosts = hosts: lib.optionalString (hosts != [ ]) ''hostname!~"${lib.concatStringsSep "|" hosts}"'';
in
{
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
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
      ])

      (mkGroup "disks" [
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

      (mkGroup "mail" [
        (mkPromAlert {
          uid = "mail-exim-queue-high";
          title = "Exim queue high";
          expr = "exim_queue";
          threshold = { type = "gt"; params = [ 500 ]; };
          for = "30m";
          summary = "{{ $values.A.Value }} messages in exim queue";
          description = "Mail is piling up, is email transport broken or are remote servers rejecting mail?";
        })
        (mkLokiAlert {
          uid = "mail-mass-outbound-mail";
          title = "Mass outbound mail";
          expr = ''
            sum by (host) (count_over_time(
              {job="systemd-journal", host="microbel", syslog_identifier="exim4"}
                | exim_type="delivery"
                | exim_transport="remote_smtp"
              [1h]
            ))
          '';
          threshold = { type = "gt"; params = [ 400 ]; };
          noDataState = "OK";
          for = "0s";
          summary = "{{ $values.A.Value }} outbound mail deliveries in the last hour";
          description = "A user may be sending spam, or the mail server may be bugging out.";
        })
      ])

      (mkGroup "postgres" (let
        pgNormalClientConnections = ''
          max by (server) (
            pg_settings_max_connections
              - pg_settings_superuser_reserved_connections
              - pg_settings_reserved_connections
          )
        '';
      in [
        (mkPromAlert {
          uid = "postgres-connections-high";
          title = "Postgres connections near limit";
          expr = ''
            sum by (server) (pg_stat_activity_count)
              / on (server) ${pgNormalClientConnections}
          '';
          threshold = { type = "gt"; params = [ 0.8 ]; };
          for = "15m";
          summary = "Postgres is using {{ humanizePercentage $values.A.Value }} of its connections";
          description = "New connections may be refused, find out who's opening all the connections and why.";
        })
        (mkPromAlert {
          uid = "postgres-connections-exhausted";
          title = "Postgres connections exhausted";
          expr = ''
            ${pgNormalClientConnections}
              - on (server) sum by (server) (pg_stat_activity_count)
          '';
          threshold = { type = "lt"; params = [ 1 ]; };
          for = "1m";
          severity = "critical";
          summary = "Postgres is refusing new connections";
          description = "All non-superuser connection slots are in use.";
        })
        (mkPromAlert {
          uid = "postgres-idle-transaction";
          title = "Postgres transaction left idle";
          expr = ''
            max by (server, datname) (
              pg_stat_activity_max_tx_duration{state=~"idle in transaction.*"}
            )
          '';
          threshold = { type = "gt"; params = [ 1800 ]; };
          for = "0s";
          summary = "Transaction in {{ $labels.datname }} has been open and idle for {{ humanizeDuration $values.A.Value }}";
          description = "Someone left a transaction idling for a long time, this prevents vacuuming and holds locks.";
        })
      ]))
    ];
  };
}
