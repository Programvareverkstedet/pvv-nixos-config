{ config, lib, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "userweb" [
      (mkPromAlert {
        uid = "userweb-nfs-excessive-traffic";
        title = "Excessive NFS traffic from userweb";
        expr = ''
          sum by (hostname, method) (
            rate(node_nfs_requests_total{hostname="temmie", job="nixos-node"}[15m])
          )
        '';
        threshold = { type = "gt"; params = [ 50 ]; };
        for = "15m";
        subject = "NFS {{ $labels.method }} on {{ $labels.hostname }}";
        summary = "50+ NFS {{ $labels.method }} calls/s for 15 minutes.";
        dashboardUrl = lib.concatStrings [
          "https://grafana.pvv.ntnu.no/d/rYdddlPWk/node-exporter-full"
          "?var-job=nixos-node"
          "&var-nodename=temmie"
          "&var-node=temmie.pvv.ntnu.no:443"
          "&from=now-6h&to=now"
        ];
      })
    ])
  ];
}
