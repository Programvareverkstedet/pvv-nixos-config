{ lib, ... }:

# NOTE: go check these resources:
# - https://samber.github.io/awesome-prometheus-alerts
# - https://github.com/search?q=lang%3Anix+provision.alerting&type=code
# - https://grafana.com/docs/grafana/latest/alerting/
#
{
  imports = [
    ./hosts.nix
    ./mail.nix
    ./postgres.nix
  ];

  lib.grafana.alerts = rec {
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

    excludeHosts = hosts: lib.optionalString (hosts != [ ]) ''hostname!~"${lib.concatStringsSep "|" hosts}"'';
  };

  services.grafana.provision.alerting.rules.settings.apiVersion = 1;
}
