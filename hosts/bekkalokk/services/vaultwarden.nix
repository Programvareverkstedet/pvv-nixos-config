{ config, pkgs, lib, values, ... }:
let
  cfg = config.services.vaultwarden;
  domain = "pw.pvv.ntnu.no";
  address = "127.0.1.2";
  port = 3011;
  wsPort = 3012;
in {
  sops.secrets."vaultwarden/rsa_key.pem" = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "440";
    restartUnits = [ "vaultwarden.service" ];
  };
  sops.secrets."vaultwarden/rsa_key.pub.pem" = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "440";
    restartUnits = [ "vaultwarden.service" ];
  };
  sops.secrets."vaultwarden/env/DATABASE_PASSWORD" = { };
  sops.secrets."vaultwarden/env/SMTP_PASSWORD" = { };
  sops.templates."vaultwarden/environment_file" = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "440";
    restartUnits = [ "vaultwarden.service" ];
    content = ''
        DATABASE_URL=postgresql://vaultwarden:${config.sops.placeholder."vaultwarden/env/DATABASE_PASSWORD"}@postgres.pvv.ntnu.no/vaultwarden
        SMTP_PASSWORD=${config.sops.placeholder."vaultwarden/env/SMTP_PASSWORD"}
    '';
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = config.sops.templates."vaultwarden/environment_file".path;
    config = {
      DOMAIN = "https://${domain}";

      ROCKET_ADDRESS = address;
      ROCKET_PORT = port;

      WEBSOCKET_ENABLED = true;
      WEBSOCKET_ADDRESS = address;
      WEBSOCKET_PORT = wsPort;

      SIGNUPS_ALLOWED = true;
      SIGNUPS_VERIFY = true;
      SIGNUPS_DOMAINS_WHITELIST = "pvv.ntnu.no";

      SMTP_FROM = "vaultwarden@pvv.ntnu.no";
      SMTP_FROM_NAME = "VaultWarden PVV";

      SMTP_HOST = "smtp.pvv.ntnu.no";
      SMTP_USERNAME = "vaultwarden";
      SMTP_SECURITY = "force_tls";
      SMTP_AUTH_MECHANISM = "Login";

      RSA_KEY_FILENAME = lib.removeSuffix ".pem" config.sops.secrets."vaultwarden/rsa_key.pem".path;
    };
  };

  systemd.services.vaultwarden = {
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

  services.rsync-pull-targets = {
    enable = true;
    locations."/var/lib/vaultwarden" = {
      user = "root";
      rrsyncArgs.ro = true;
      authorizedKeysAttrs = [
        "restrict"
        "from=\"principal.pvv.ntnu.no,${values.hosts.principal.ipv6},${values.hosts.principal.ipv4}\""
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB2cDaW52gBtLVaNqoGijvN2ZAVkAWlII5AXUzT3Dswj vaultwarden rsync backup";
    };
  };
}
