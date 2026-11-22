{ config, lib, ... }:
let
  mcfg = config.services.pvv-userweb;
in
{
  services.nginx = lib.mkIf mcfg.enable {
    enable = true;

    upstreams.userweb-httpd.servers."127.0.0.1:${toString mcfg.httpdPort}" = { };

    virtualHosts."temmie.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;

      serverAliases = [
        "www2.pvv.ntnu.no"
      ];

      locations."/" = {
        proxyPass = "http://userweb-httpd";
        extraConfig = ''
          # NOTE: should match `post_max_size`/`upload_max_filesize` in the PHP options.
          client_max_body_size 40M;

          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
        '';
      };
    };
  };
}
