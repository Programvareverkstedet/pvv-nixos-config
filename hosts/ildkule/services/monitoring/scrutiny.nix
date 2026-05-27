{ config, values, ... }:
let
  cfg = config.services.scrutiny;
in
{
  services.scrutiny = {
    enable = true;
    settings = {
      web.listen = {
        host = "127.0.0.1";
        port = 18293;
        basepath = "";
      };

      # notify.urls = [
      #   "matrix://username:password@host:port/[?rooms=!roomID1[,roomAlias2]]"
      # ];
    };
  };

  services.nginx.virtualHosts."scrutiny.pvv.ntnu.no" = {
    kTLS = true;
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${cfg.settings.web.listen.host}:${toString cfg.settings.web.listen.port}";
    };

    # TODO: allow website access to the outside world, but restrict input api
    extraConfig = ''
      allow ${values.hosts.ildkule.ipv4}/32;
      allow ${values.hosts.ildkule.ipv6}/128;
      allow 127.0.0.1/32;
      allow ::1/128;
      allow ${values.ipv4-space};
      allow ${values.ipv6-space};
      deny all;
    '';
  };
}
