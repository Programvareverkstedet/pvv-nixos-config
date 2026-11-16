{ config, lib, ... }:
let
  cfg = config.services.alps;
in
{
  services.alps = {
    enable = true;
    settings = {
      server.addr = "127.0.0.1:1323";
      smtp.server = "smtp.pvv.ntnu.no";
      imap.server = "imap.pvv.ntnu.no";
    };
  };

  services.nginx.virtualHosts."alps.pvv.ntnu.no" = lib.mkIf cfg.enable {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://${cfg.settings.server.addr}";
    };
  };
}
