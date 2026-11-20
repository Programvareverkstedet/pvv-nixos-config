{ lib, ... }:
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
          annotations.dashboard_url = lib.concatStrings [
            "https://grafana.pvv.ntnu.no/d/rYdddlPWk/node-exporter-full"
            "?var-job={{ $labels.job }}"
            "&var-nodename={{ $labels.hostname }}"
            "&var-node={{ $labels.instance }}"
            "&from=now-6h&to=now"
          ];
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
    ];
  };
}
