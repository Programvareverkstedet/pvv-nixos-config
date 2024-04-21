{ config, pkgs, lib, ... }:
let
  cfg = config.services.uptime-kuma;
  domain = "status.pvv.ntnu.no";
in {
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "5059";
      HOST = "127.0.1.2";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/".proxyPass = "http://${cfg.settings.HOST}:${cfg.settings.PORT}";
  };
}
