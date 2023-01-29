{ config, ... }:
{
  services.nginx = {
    enable = true;

    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts = {
      "www.pvv.ntnu.no" = {
        forceSSL = true;

        locations = {
          "/pvv" = {
            proxyPass = "http://localhost:${config.services.mediawiki.virtualHost.listen.pvv.port}";
          };
        };
      };

      "git.pvv.ntnu.no" = {
        locations."/" = {
          proxyPass = "http://unix:${config.services.gitea.settings.server.HTTP_ADDR}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
