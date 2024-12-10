{ ... }:
{
  systemd.services.logrotate = {
    documentation = [ "man:logrotate(8)" "man:logrotate.conf(5)" ];
    unitConfig.RequiresMountsFor = "/var/log";
    serviceConfig.ReadWritePaths = [ "/var/log" ];
  };
}
