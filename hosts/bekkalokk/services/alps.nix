{ config, lib, ... }:
let
  cfg = config.services.alps;
in
{
  services.alps = {
    enable = true;
    theme = "sourcehut";
    smtps.host = "smtp.pvv.ntnu.no";
    imaps.host = "imap.pvv.ntnu.no";
    bindIP = "127.0.0.1";
  };

  services.nginx.virtualHosts."alps.pvv.ntnu.no" = lib.mkIf cfg.enable {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
    };
  };
}
