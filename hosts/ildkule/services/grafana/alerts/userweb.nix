{ config, lib, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkLokiAlert mkGroup;

  mkAuditAlert = {
    key,
    syscall ? null,
    fields ? { },
    severity ? "warning",
    ...
  }@args: let
    jsonFields = {
      audit_key = "SYSCALL.key";
      audit_exe = "SYSCALL.exe";
    } // lib.optionalAttrs (syscall != null) {
      audit_syscall = "SYSCALL.SYSCALL";
    } // fields;
  in mkLokiAlert (
    { inherit severity; }
    // removeAttrs args [ "key" "syscall" "fields" ]
    // {
      # NOTE: summing here not to instantly resolve the alert.
      expr = ''
        sum by (${lib.concatStringsSep ", " ([ "host" "audit_exe" ] ++ lib.attrNames fields)}) (count_over_time(
          {job="systemd-journal", syslog_identifier="auditd"}
            |= `"key":"${key}"`
            | json ${lib.concatStringsSep ", " (lib.mapAttrsToList (name: path: "${name}=\"${path}\"") jsonFields)}
            | audit_key="${key}"${lib.optionalString (syscall != null) " and audit_syscall=\"${syscall}\""}
          [30m]
        ))
      '';
      labels.hostname = "{{ $labels.host }}";
      for = "0s";
    }
  );
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "userweb" [
      (mkPromAlert {
        uid = "userweb-nfs-excessive-traffic";
        title = "Excessive NFS traffic from userweb";
        expr = ''
          sum by (hostname, method) (
            rate(node_nfs_requests_total{hostname="temmie", job="nixos-node"}[15m])
          )
        '';
        threshold = { type = "gt"; params = [ 50 ]; };
        for = "15m";
        subject = "NFS {{ $labels.method }} on {{ $labels.hostname }}";
        summary = "50+ NFS {{ $labels.method }} calls/s for 15 minutes.";
        dashboardUrl = lib.concatStrings [
          "https://grafana.pvv.ntnu.no/d/rYdddlPWk/node-exporter-full"
          "?var-job=nixos-node"
          "&var-nodename=temmie"
          "&var-node=temmie.pvv.ntnu.no:443"
          "&from=now-6h&to=now"
        ];
      })

      (mkAuditAlert {
        uid = "audit-userweb-bind";
        title = "Userweb tried to bind a socket";
        key = "userweb-bind";
        syscall = "bind";
        fields.audit_saddr = "SOCKADDR[0].SADDR";
        subject = "{{ $labels.audit_exe }} on {{ $labels.host }}";
        summary = "The httpd user tried to bind {{ $labels.audit_saddr }}.";
      })

      (mkAuditAlert {
        uid = "audit-userweb-listen";
        title = "Userweb tried to listen on a socket";
        key = "userweb-bind";
        syscall = "listen";
        subject = "{{ $labels.audit_exe }} on {{ $labels.host }}";
        summary = "The httpd user called listen() on a socket.";
      })

      (mkAuditAlert {
        uid = "audit-userweb-exec";
        title = "Userweb ran a program from a temp directory";
        key = "userweb-exec";
        fields = {
          audit_path = "PATH[0].name";
          audit_parent = "SYSCALL.PPID.exe";
        };
        subject = "{{ $labels.audit_path }} on {{ $labels.host }}";
        summary = ''
          wwwrun ran {{ $labels.audit_path }} ({{ $labels.audit_exe }}) from /tmp or /var/tmp

          parent {{ $labels.audit_parent }}.
        '';
      })
    ])
  ];
}
