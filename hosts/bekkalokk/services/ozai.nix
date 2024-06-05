{ config, pkgs, lib, ... }:
let
  domain = "azul.pvv.ntnu.no";
in
{

  services.ozai.enable = true;
  services.ozai.host = "0.0.0.0";
  services.ozai.port = 8000;

  services.ozai-webui = {
    enable = true;
    port = 8085;
    host = "127.0.0.1";
  };

  services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyWebsockets = true;
        proxyPass = "http://${config.services.ozai.host}:${config.services.ozai.port}";
      };
  };
}
