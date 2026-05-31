{ config, lib, ... }:
let
  domain = "dav.pvv.ntnu.no";
  radicalePort = 5232;
in {
  services.radicale = {
    enable = true;

    settings = {
      server = {
        hosts = [ "127.0.0.1:${toString radicalePort}" ];
      };

      auth = {
        type = "imap";
        imap_host = "imap.pvv.ntnu.no";
        imap_security = "tls";
      };

      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;

    extraConfig = ''
      client_max_body_size 128M;
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString radicalePort}";
      proxyWebsockets = true;
    };
  };
}
