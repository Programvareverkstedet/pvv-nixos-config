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
  }: {
    inherit uid title for noDataState;
    condition = "B";
    execErrState = "Error";
    labels = { inherit severity; };
    annotations = { inherit summary; } // lib.optionalAttrs (description != null) { inherit description; };
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
    ];
  };
}
