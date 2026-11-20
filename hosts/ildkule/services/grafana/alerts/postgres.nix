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
    ])
  ];
}
