{ config, pkgs, lib, ... }:
let
  cfg = config.services.vaultwarden;
  domain = "pw.pvv.ntnu.no";
  address = "127.0.1.2";
  port = 3011;
  wsPort = 3012;
in {
  sops.secrets."vaultwarden/environ" = {
    owner = "vaultwarden";
    group = "vaultwarden";
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = config.sops.secrets."vaultwarden/environ".path;
    config = {
      domain = "https://${domain}";

      rocketAddress = address;
      rocketPort = port;

      websocketEnabled = true;
      websocketAddress = address;
      websocketPort = wsPort;

      signupsAllowed = true;
      signupsVerify = true;
      signupsDomainsWhitelist = "pvv.ntnu.no";

      smtpFrom = "vaultwarden@pvv.ntnu.no";
      smtpFromName = "VaultWarden PVV";

      smtpHost = "smtp.pvv.ntnu.no";
      smtpUsername = "vaultwarden";
      smtpSecurity = "force_tls";
      smtpAuthMechanism = "Login";

      # Configured in environ:
      # databaseUrl = "postgresql://vaultwarden@/vaultwarden";
      # smtpPassword = hemli
    };
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;

    extraConfig = ''
      client_max_body_size 128M;
    '';

    locations."/" = {
      proxyPass = "http://${address}:${toString port}";
      proxyWebsockets = true;
    };
    locations."/notifications/hub" = {
      proxyPass = "http://${address}:${toString wsPort}";
      proxyWebsockets = true;
    };
    locations."/notifications/hub/negotiate" = {
      proxyPass = "http://${address}:${toString port}";
      proxyWebsockets = true;
    };
  };
}
