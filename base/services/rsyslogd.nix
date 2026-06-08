{ ... }:
{
  services.rsyslogd = {
    enable = true;
    defaultConfig = ''
      *.* @loghost.pvv.ntnu.no
    '';
  };

  services.journald.extraConfig = ''
    ForwardToSyslog=yes
  '';
}
