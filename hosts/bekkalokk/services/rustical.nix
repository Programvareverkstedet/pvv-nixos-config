{ config, lib, ... }:
let
  domain = "dav.pvv.ntnu.no";
  port = 4000;
in {
  sops.secrets."rustical/client_id" = {
    restartUnits = [ "rustical.service" ];
  };
  sops.secrets."rustical/client_secret" = {
    restartUnits = [ "rustical.service" ];
  };
  sops.templates."rustical/environment_file" = {
    restartUnits = [ "rustical.service" ];
    content = ''
      RUSTICAL_OIDC__CLIENT_ID=${config.sops.placeholder."rustical/client_id"}
      RUSTICAL_OIDC__CLIENT_SECRET=${config.sops.placeholder."rustical/client_secret"}
    '';
  };

  services.rustical = {
    enable = true;
    environmentFiles = [ config.sops.templates."rustical/environment_file".path ];
    settings = {
      http = {
        host = "127.0.0.1";
        port = port;
      };
      oidc = {
        name = "PVV";
        issuer = "https://git.pvv.ntnu.no";
        claim_userid = "preferred_username";
        scopes = [ "openid" "profile" ];
        allow_sign_up = true;
      };
      frontend.allow_password_login = false;
    };
  };

  systemd.services.rustical = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;

    extraConfig = ''
      client_max_body_size 128M;
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}
