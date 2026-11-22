{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;

  increase = metric: window: ''sum by (hostname, name) (increase(${metric}[${window}]))'';
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "fluent-bit" [
      (mkPromAlert {
        uid = "fluent-bit-output-stalled";
        title = "Fluent-bit stopped delivering logs";

        # NOTE: this expression reads backwards, the "unless" clause is the case that says
        #       "we are not delivering anything", and the first part is to ignore the case
        #       where no chunks are waiting to be retried (i.e. it's probably just quiet).
        expr = ''
          ${increase "fluentbit_output_retries_total" "15m"} > 0
            unless on (hostname, name) ${increase "fluentbit_output_proc_records_total" "5m"} > 0
        '';
        subject = "{{ $labels.hostname }} ({{ $labels.name }})";
        summary = "No records delivered for 5+ minutes while flushes are failing.";
      })

      (mkPromAlert {
        uid = "fluent-bit-dropped-rejected";
        title = "Fluent-bit dropped logs rejected by Loki";
        expr = increase "fluentbit_output_errors_total" "5m";
        for = "0s";
        subject = "{{ $labels.hostname }} ({{ $labels.name }})";
        summary = "{{ humanize $values.A.Value }} chunks dropped, Loki answers HTTP 4XX or 5XX.";
      })
    ])
  ];
}
