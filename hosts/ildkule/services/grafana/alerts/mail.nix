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
        description = "A user may be sending spam, or the mail server may be bugging out.";
      })
    ])
  ];
}
