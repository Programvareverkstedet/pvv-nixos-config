{ config, pkgs, ... }:

{
  services.grafana = {
    enable = true;
    settings.server = {
      domain = "ildkule.pvv.ntnu.no";
      http_port = 2342;
      http_addr = "127.0.0.1";
    };
  };

  services.nginx.virtualHosts.${config.services.grafana.domain} = {
    locations = {
      "/" = {
        proxyPass = "http://${config.services.grafana.addr}:${toString config.services.grafana.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffers 8 1024k;
          proxy_buffer_size 1024k;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
