{ config, lib, pkgs, ... }:
let
  cfg = config.services.garage;
in
{
  sops.secrets = lib.mkIf cfg.enable {
    "garage/rpc-secret" = {
      owner = "garage";
      group = "garage";
      restartUnits = [ "garage.service" ];
    };
    "garage/admin-token" = {
      owner = "garage";
      group = "garage";
      restartUnits = [ "garage.service" ];
    };
    "garage/metrics-token" = {
      owner = "garage";
      group = "garage";
      restartUnits = [ "garage.service" ];
    };
  };

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    settings = {
      data_dir = [
        {
          capacity = "50G";
          path = "/var/lib/garage/data";
        }
      ];
      metadata_dir = "/var/lib/garage/meta";
      db_engine = "lmdb";
      replication_factor = 1;

      rpc_bind_addr = "[::]:3901";
      rpc_secret_file = config.sops.secrets."garage/rpc-secret".path;

      s3_api = {
        s3_region = "eu-central";
        api_bind_addr = "[::]:3900";
        root_domain = ".garage.pvv.ntnu.no";
      };

      # s3_web = {
      #   bind_addr = "[::]:3902";
      #   root_domain = ".garage-web.pvv.ntnu.no";
      #   index = "index.html";
      # };

      admin = {
      #   api_bind_addr = "[::]:3903";
        admin_token_file = config.sops.secrets."garage/admin-token".path;
        metrics_token_file = config.sops.secrets."garage/metrics-token".path;
      };
    };
  };

  users = lib.mkIf cfg.enable {
    users.garage = {
      isSystemUser = true;
      group = "garage";
    };
    groups.garage = { };
  };

  systemd.tmpfiles.settings."10-garage" = lib.mkIf cfg.enable {
    "/data/garage/data".d = {
      user = "garage";
      group = "garage";
      mode = "0770";
    };
    "/data/garage/meta".d = {
      user = "garage";
      group = "garage";
      mode = "0770";
    };
  };

  systemd.services.garage = lib.mkIf cfg.enable {
    serviceConfig = {
      DynamicUser = false;
      User = "garage";
      Group = "garage";

      BindReadWritePaths = [
        "/data/garage/data:/var/lib/garage/data"
        "/data/garage/meta:/var/lib/garage/meta"
      ];

      LoadCredential = [
        "rpc_secret_path:${config.sops.secrets."garage/rpc-secret".path}"
        "admin_token_path:${config.sops.secrets."garage/admin-token".path}"
        "metrics_token_path:${config.sops.secrets."garage/metrics-token".path}"
      ];

      Environment = [
        "GARAGE_ALLOW_WORLD_READABLE_SECRETS=true"
        "GARAGE_RPC_SECRET_FILE=%d/rpc_secret_path"
        "GARAGE_ADMIN_TOKEN_FILE=%d/admin_token_path"
        "GARAGE_METRICS_TOKEN_FILE=%d/metrics_token_path"
      ];
    };
  };

  services.nginx = lib.mkIf cfg.enable {
    upstreams.s3_backend.servers = {
      "[::1]:3900" = { };
    };
    # upstreams.web_backend.servers = {
    #   "[::1]:3902" = { };
    # };

    virtualHosts."garage.pvv.ntnu.no" = {
      serverAliases = [ "*.garage.pvv.ntnu.no" ];

      enableACME = true;
      # useACMEHost = "garage.pvv.ntnu.no";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://s3_backend";
        extraConfig = ''
          client_max_body_size 64m;
          proxy_max_temp_file_size 0;
        '';
      };
    };

    # virtualHosts."garage-web.pvv.ntnu.no" = {
    #   serverAliases = [ "*.garage-web.pvv.ntnu.no" ];

    #   useACMEHost = "garage-web.pvv.ntnu.no";
    #   forceSSL = true;

    #   locations."/" = {
    #     proxyPass = "http://web_backend";
    #   };
    # };
  };
}
