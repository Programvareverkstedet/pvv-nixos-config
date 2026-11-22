{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;

  pgNormalClientConnections = ''
    max by (server) (
      pg_settings_max_connections
        - pg_settings_superuser_reserved_connections
        - pg_settings_reserved_connections
    )
  '';
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "postgres" [
      (mkPromAlert {
        uid = "postgres-connections-high";
        title = "Postgres connections near limit";
        expr = ''
          sum by (server) (pg_stat_activity_count)
            / on (server) ${pgNormalClientConnections}
        '';
        threshold = { type = "gt"; params = [ 0.8 ]; };
        for = "15m";
        summary = "More than 80% of non-superuser connection slots are in use.";
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
        summary = "All non-superuser connection slots are in use, so new connections are refused.";
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
        subject = "{{ $labels.datname }}";
        description = "Someone left a transaction idling for a long time, this prevents vacuuming and holds locks.";
      })
    ])
  ];
}
