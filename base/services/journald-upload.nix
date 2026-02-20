{
  config,
  lib,
  values,
  ...
}:
let
  cfg = config.services.journald.upload;
in
{
  services.journald.upload = {
    enable = lib.mkDefault true;
    settings.Upload = {
      # URL = "https://journald.pvv.ntnu.no:${toString config.services.journald.remote.port}";
      URL = "https://${values.hosts.ildkule.ipv4}:${toString config.services.journald.remote.port}";
      ServerKeyFile = "-";
      ServerCertificateFile = "-";
      TrustedCertificateFile = "-";
    };
  };

  systemd.services."systemd-journal-upload".serviceConfig = lib.mkIf cfg.enable {
    IPAddressDeny = "any";
    IPAddressAllow = [
      values.hosts.ildkule.ipv4
      values.hosts.ildkule.ipv6
    ];
  };
}
