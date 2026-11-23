{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;

  mkNoTrafficAlert = type: name: mkPromAlert {
    uid = "matrix-ooye-no-${type}-traffic";
    title = "OOYE stopped bridging ${name} messages";
    expr = ''changes(ooye_messages_total{job="matrix-ooye", type="${type}"}[24h])'';
    threshold = { type = "lt"; params = [ 1 ]; };
    summary = "No new messages in the last 24 hours.";
    dashboardUrl = "https://grafana.pvv.ntnu.no/d/matrix-ooye";
    labels.hostname = "bicep";
  };
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "matrix-ooye" [
      (mkNoTrafficAlert "discord" "Discord")
      (mkNoTrafficAlert "matrix" "Matrix")

      (mkPromAlert {
        uid = "matrix-ooye-homeserver-offline";
        title = "OOYE can't connect to the Matrix homeserver";
        expr = ''ooye_homeserver_online{job="matrix-ooye"}'';
        threshold = { type = "lt"; params = [ 1 ]; };
        summary = "Reported offline for 5+ minutes.";
        dashboardUrl = "https://grafana.pvv.ntnu.no/d/matrix-ooye";
        labels.hostname = "bicep";
      })

      (mkPromAlert {
        uid = "matrix-ooye-homeserver-queue-stuck";
        title = "OOYE homeserver queue not draining";
        expr = ''min_over_time(ooye_homeserver_queue_length{job="matrix-ooye"}[30m])'';
        threshold = { type = "gt"; params = [ 0 ]; };
        for = "0s";
        summary = "Events have been waiting for 30+ minutes.";
        dashboardUrl = "https://grafana.pvv.ntnu.no/d/matrix-ooye";
        labels.hostname = "bicep";
      })
    ])
  ];
}
