{ lib, ... }:
{
  # Serves PVV themed error pages on vhosts nginx hosts itself; proxied vhosts
  # default to the plain nginx error pages.
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }: {
          options.pvv-custom-http-error-pages = lib.mkOption {
            type = lib.types.bool;
            description = ''
              Whether to serve PVV's custom error pages for 500, 502 and 503
              responses. Defaults to false when `locations."/".proxyPass` is
              set, true otherwise.
            '';
          };

          config = {
            pvv-custom-http-error-pages = lib.mkDefault ((config.locations."/".proxyPass or null) == null);

            extraConfig = lib.mkIf config.pvv-custom-http-error-pages ''
              error_page 500 /500.html;
              error_page 502 /502.html;
              error_page 503 /503.html;

              location ~ ^/(500|502|503)\.html$ {
                root ${./http-error-pages};
                internal;
              }
            '';
          };
        }
      )
    );
  };

  config.services.nginx.enable = true;
}
