{ lib, ... }:

# NOTE: go check these resources:
# - https://samber.github.io/awesome-prometheus-alerts
# - https://github.com/search?q=lang%3Anix+provision.alerting&type=code
# - https://grafana.com/docs/grafana/latest/alerting/
#
{
  imports = [
    ./certificates.nix
    ./exporters.nix
    ./fluent-bit.nix
    ./hosts.nix
    ./mail.nix
    ./matrix-ooye.nix
    ./matrix-synapse.nix
    ./postgres.nix
    ./smart.nix
    ./userweb.nix
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

      # Should contain dynamically rendered parts pointing at which instance is affected
      subject ? null,

      # Should contain a brief description of the problem.
      # Preferably accurately what the alert monitors, rather than what it might (or mightn not) imply.
      summary ? null,

      # Should contain speculation about what might be wrong and where to go looking.
      description ? null,

      # If overridden, point to a dashboard that might help give a broader picture of the alert.
      dashboardUrl ? null,

      # Whether no data from the query should be treated as an alert state.
      noDataState ? "OK",

      execErrState ? if for == "0s" then "KeepLast" else "Error",
      labels ? { },
      annotations ? { },
    }:
    assert (lib.elem severity [ "critical" "warning" ]);
    assert (lib.elem noDataState [ "NoData" "OK" "Alerting" ]);
    assert (lib.elem execErrState [ "Error" "OK" "Alerting" "KeepLast" ]);
    assert (lib.elem threshold.type [ "gt" "lt" "eq" ]);
    {
      inherit uid title for noDataState execErrState;
      condition = "B";
      labels = { inherit severity; } // labels;
      annotations =
           lib.optionalAttrs (dashboardUrl != null) { inherit dashboardUrl; }
        // lib.optionalAttrs (summary != null) { inherit summary; }
        // lib.optionalAttrs (subject != null) { inherit subject; }
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
      inherit name;
      rules = lib.flatten rules;
      folder = "Infrastructure";
      interval = "1m";
    };

    nodeJobs = ''job=~"nixos-node|non-nixos-node"'';
    icmpJobs = ''job=~"blackbox-icmp4|blackbox-icmp6"'';
    hostDown = ''max by (hostname) (probe_success{${icmpJobs}}) == 0'';

    excludeHosts = hosts: lib.optionalString (hosts != [ ]) ''hostname!~"${lib.concatStringsSep "|" hosts}"'';
  };

  services.grafana.provision.alerting.rules.settings.apiVersion = 1;
}
