{ config, lib, ... }:
{
  # Apply a shared error page theme to every nginx vhost.
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.extraConfig = lib.mkDefault ''
        error_page 500 /500.html;
        error_page 502 /502.html;
        error_page 503 /503.html;
        location ~ ^/(500|502|503)\.html$ {
          root ${./http-error-pages};
          internal;
        }
      '';
    });
  };

  config.services.nginx.enable = true;
}
