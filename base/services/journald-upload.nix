{ config, lib, values, ... }:
let
  cfg = config.services.journald.upload;
in
{
  services.journald.upload = {
    enable = lib.mkDefault true;
    settings.Upload = {
      URL = "https://journald.pvv.ntnu.no:${toString config.services.journald.remote.port}";
      ServerKeyFile = "-";
      ServerCertificateFile = "-";
      TrustedCertificateFile = "-";
    };
  };

  systemd.services."systemd-journal-upload".serviceConfig = lib.mkIf cfg.enable {
    IPAddressDeny = "any";
    IPAddressAllow = [
      "127.0.0.1"
      "::1"
      values.ipv4-space
      values.ipv6-space
    ];
  };
}
