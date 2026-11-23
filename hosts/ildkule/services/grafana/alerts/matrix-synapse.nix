{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;

  dashboardUrl = "https://grafana.pvv.ntnu.no/d/000000012";
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
        inherit dashboardUrl;
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
        inherit dashboardUrl;
        labels.hostname = "bicep";
      })

      (mkPromAlert {
        uid = "matrix-synapse-event-processing-lag";
        title = "Synapse event processing not keeping up";
        expr = ''
          max by (name) (
            synapse_event_processing_lag{instance="matrix.pvv.ntnu.no"}
          )
        '';
        threshold = { type = "gt"; params = [ 1500 ]; };
        for = "30m";
        subject = "{{ $labels.name }}";
        summary = "Over 1500 events behind for 30+ minutes.";
        inherit dashboardUrl;
        labels.hostname = "bicep";
      })
    ])
  ];
}
