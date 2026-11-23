{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "matrix-synapse" [
      (mkPromAlert {
        uid = "matrix-synapse-no-incoming-federation";
        title = "Synapse receives no federation traffic";
        expr = ''
          sum(
            increase(
              synapse_http_server_requests_received_total{
                instance="matrix.pvv.ntnu.no",
                servlet="FederationSendServlet"
              }[1h]
            )
          )
        '';
        threshold = { type = "lt"; params = [ 100 ]; };
        for = "15m";
        summary = "Less than 100 incoming fed transactions in the last hour.";
        dashboardUrl = "https://grafana.pvv.ntnu.no/d/000000012";
        labels.hostname = "bicep";
      })

      (mkPromAlert {
        uid = "matrix-synapse-federation-queue-stuck";
        title = "Synapse federation queue is stuck";
        expr = ''
          max by (job, index) (
            min_over_time(
              synapse_federation_transaction_queue_pending_pdus{instance="matrix.pvv.ntnu.no"}[30m]
            )
          )
        '';
        threshold = { type = "gt"; params = [ 100 ]; };
        for = "0s";
        subject = "{{ $labels.job }}/{{ $labels.index }}";
        summary = "Over 100 events waiting in fed queue for 30+ minutes.";
        dashboardUrl = "https://grafana.pvv.ntnu.no/d/000000012";
        labels.hostname = "bicep";
      })
    ])
  ];
}
