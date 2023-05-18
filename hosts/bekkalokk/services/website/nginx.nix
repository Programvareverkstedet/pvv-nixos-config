{ pkgs, config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "drift@pvv.ntnu.no";
  };

  services.nginx = {
    enable = true;

    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts = {
      "bekkalokk.pvv.ntnu.no" = {
        forceSSL = true;
        enableACME = true;
        root = "${config.services.mediawiki.finalPackage}/share/mediawiki";
        locations =  {
          "/" = {
            extraConfig = ''
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_index index.php;
              fastcgi_pass unix:${config.services.phpfpm.pools.mediawiki.socket};
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
            '';
          };

	  "/images".root = config.services.mediawiki.uploadsDir;

          # "/git" = {
          #   proxyPass = "http://unix:${config.services.gitea.settings.server.HTTP_ADDR}";
          #   proxyWebsockets = true;
          # };
        };
      };
    };
  };
}
