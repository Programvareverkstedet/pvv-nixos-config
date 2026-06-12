{ config, lib, ... }:
let
  cfg = config.services.rsyslogd;
in
{
  services.rsyslogd = {
    enable = lib.mkDefault true;
    defaultConfig = ''
      *.* @loghost.pvv.ntnu.no
    '';
  };

  services.journald.extraConfig = lib.mkIf cfg.enable ''
    ForwardToSyslog=yes
  '';

  systemd.services = lib.mkIf cfg.enable {
    "syslog".serviceConfig.Slice = "system-monitoring.slice";
  };
}
