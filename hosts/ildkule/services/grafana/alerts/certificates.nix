{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;

  certificateJob = ''job="blackbox-certificate"'';

  mkExpiryAlert = { days, severity }: mkPromAlert {
    inherit severity;
    uid = "certificates-expiring-${toString days}";
    title = "TLS certificate expires in < ${toString days} days";
    expr = ''
      (probe_ssl_last_chain_expiry_timestamp_seconds{${certificateJob}} - time()) / 86400
    '';
    threshold = { type = "lt"; params = [ days ]; };
    for = "1h";
    noDataState = "OK";
    summary = "Certificate for {{ $labels.instance }} expires in {{ humanize $values.A.Value }} days";
    description = "Check the acme renewal unit or certbot to see if it's spitting errors";
  };
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "certificates" [
      (mkExpiryAlert { days = 14; severity = "warning"; })
      (mkExpiryAlert { days = 3; severity = "critical"; })
      (mkExpiryAlert { days = 2; severity = "critical"; })
      (mkExpiryAlert { days = 1; severity = "critical"; })

      (mkPromAlert {
        uid = "certificates-acme-renewal-failed";
        title = "ACME renewal failed";
        expr = ''systemd_unit_state{name=~"acme-.+\\.service", state="failed"}'';
        for = "15m";
        noDataState = "OK";
        summary = "{{ $labels.name }} failed on {{ $labels.hostname }}";
        description = "Check `journalctl -eu {{ $labels.name }}` on {{ $labels.hostname }}.";
      })
    ])
  ];
}
