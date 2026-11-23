{ config, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkLokiAlert mkGroup;
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "mail" [
      (mkPromAlert {
        uid = "mail-exim-queue-high";
        title = "Exim queue high";
        expr = "exim_queue";
        threshold = { type = "gt"; params = [ 500 ]; };
        for = "30m";
        labels.hostname = "microbel";
        description = "Mail is piling up, is email transport broken or are remote servers rejecting mail?";
      })

      (mkLokiAlert {
        uid = "mail-mass-outbound-mail";
        title = "Mass outbound mail";
        expr = ''
          sum by (host) (count_over_time(
            {job="systemd-journal", host="microbel", syslog_identifier="exim4"}
              | exim_type="delivery"
              | exim_transport="remote_smtp"
            [1h]
          ))
        '';
        threshold = { type = "gt"; params = [ 400 ]; };
        for = "0s";
        labels.hostname = "microbel";
        description = "A user may be sending spam, or the mail server may be bugging out.";
      })

      (mkPromAlert {
        uid = "mail-inbound-stalled";
        title = "Inbound mail stalled";
        expr = ''increase(exim_messages_total{flag="arrived"}[6h])'';
        threshold = { type = "lt"; params = [ 5 ]; };
        for = "0s";
        labels.hostname = "microbel";
        summary = "Fewer than 5 messages arrived in the last 6 hours.";
      })

      (mkLokiAlert {
        uid = "mail-incoming-queued-no-home";
        title = "Incoming mail queued for unreachable home directories";
        expr = ''
          count by (host) (sum by (host, exim_recipient) (count_over_time(
            {job="systemd-journal", host="microbel", syslog_identifier="exim4"}
              | exim_type="delivery"
              | exim_reason="no_home"
            [1h]
          )))
        '';
        threshold = { type = "gt"; params = [ 3 ]; };
        for = "0s";
        labels.hostname = "microbel";
        summary = "Mail to 3+ users queued in an hour due to unreachable homedirs.";
      })

      (mkPromAlert {
        uid = "mail-imap-logins-stalled";
        title = "IMAP/POP3 logins stalled";
        expr = ''increase(dovecot_auth_successes_total[1h])'';
        threshold = { type = "lt"; params = [ 10 ]; };
        for = "0s";
        severity = "critical";
        labels.hostname = "microbel";
        summary = "Less than 10 successful IMAP/POP3 logins in the last hour.";
      })
    ])
  ];
}
