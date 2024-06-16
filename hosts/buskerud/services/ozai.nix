{ config, pkgs, lib, ... }:
let
domain = "buskerud.pvv.ntnu.no";
in
{

  services.ozai = {
    enable = true;
    host = "0.0.0.0";
    port = 8000;
  };

  services.ozai-webui = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
  };

  services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/azul/" = {
        proxyWebsockets = true;
        proxyPass = "http://${config.services.ozai-webui.host}:${config.services.ozai-webui.port}";
      };
       locations."/ozai/" = {
        proxyWebsockets = true;
        proxyPass = "http://${config.services.ozai.host}:${config.services.ozai.port}";
      };
    };


}
