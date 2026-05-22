{ config, pkgs, lib, values, ... }:
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
    mode = "440";
  };
  sops.secrets."vaultwarden/rsa_key.pem" = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "440";
  };
  sops.secrets."vaultwarden/rsa_key.pub.pem" = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "440";
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = config.sops.secrets."vaultwarden/environ".path;
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

      # Configured in environ:
      # DATABASE_URL = "postgresql://vaultwarden@/vaultwarden";
      # SMTP_PASSWORD = hemli
    };
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

  systemd.services.vaultwarden = lib.mkIf cfg.enable {
    serviceConfig = {
      AmbientCapabilities = [ "" ];
      CapabilityBoundingSet = [ "" ];
      DeviceAllow = [ "" ];
      LockPersonality = true;
      NoNewPrivileges = true;
      # MemoryDenyWriteExecute = true;
      PrivateMounts = true;
      PrivateUsers = true;
      ProcSubset = "pid";
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
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
