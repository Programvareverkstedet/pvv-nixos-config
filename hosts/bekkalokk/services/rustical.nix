{ config, lib, ... }:
let
  cfg = config.services.rustical;
  domain = "dav.pvv.ntnu.no";
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
      http.bind = "127.0.0.1:4000";
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
    environment.NO_COLOR = "1";
  };

  services.nginx.upstreams.rustical.servers."${cfg.settings.http.bind}" = { };

  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;

    extraConfig = ''
      client_max_body_size 128M;
    '';

    locations."/" = {
      proxyPass = "http://rustical";
      proxyWebsockets = true;
    };
  };
}
