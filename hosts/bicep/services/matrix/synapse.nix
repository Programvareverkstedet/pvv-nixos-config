{ config, lib, fp, pkgs, values, inputs, ... }:

let
  cfg = config.services.matrix-synapse-next;

  matrix-lib = inputs.matrix-next.lib;

  imap0Attrs = with lib; f: set:
    listToAttrs (imap0 (i: attr: nameValuePair attr (f i attr set.${attr})) (attrNames set));
in {
  sops.secrets."matrix/synapse/signing_key" = {
    key = "synapse/signing_key";
    sopsFile = fp /secrets/bicep/matrix.yaml;
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  sops.secrets."matrix/synapse/user_registration" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "synapse/signing_key";
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  services.matrix-synapse-next = {
    enable = true;

    plugins = [
      (pkgs.python3Packages.callPackage ./smtp-authenticator { })
    ];

    dataDir = "/data/synapse";

    workers.federationSenders = 2;
    workers.federationReceivers = 2;
    workers.initialSyncers = 1;
    workers.normalSyncers = 1;
    workers.eventPersisters = 2;
    workers.useUserDirectoryWorker = true;

    enableNginx = true;

    settings = {
      server_name = "pvv.ntnu.no";
      public_baseurl = "https://matrix.pvv.ntnu.no";

      signing_key_path = config.sops.secrets."matrix/synapse/signing_key".path;

      media_store_path =  "${cfg.dataDir}/media";

      database = {
        name = "psycopg2";
        args = {
          host = "/var/run/postgresql";
          dbname = "synapse";
          user = "matrix-synapse";
          cp_min = 1;
          cp_max = 5;
        };
      };

      presence.enabled = false;

      event_cache_size = "20K"; # Default is 10K but I can't find the factor for this cache
      caches = {
        per_cache_factors = {
          _event_auth_cache = 2.0;
        };
      };

      autocreate_auto_join_rooms = false;
      auto_join_rooms = [
        "#pvv:pvv.ntnu.no" # Main space
        "#announcements:pvv.ntnu.no"
        "#general:pvv.ntnu.no"
      ];

      allow_public_rooms_over_federation = true;

      max_upload_size = "150M";

      enable_metrics = true;
      mau_stats_only = true;

      enable_registration = false;
      registration_shared_secret_path = config.sops.secrets."matrix/synapse/user_registration".path;

      password_config.enabled = true;

      modules = [
        { module = "smtp_auth_provider.SMTPAuthProvider";
          config = {
            smtp_host = "smtp.pvv.ntnu.no";
          };
        }
      ];

      trusted_key_servers = [
        { server_name = "matrix.org"; }
        { server_name = "dodsorf.as"; }
      ];

      url_preview_enabled = true;
      url_preview_ip_range_blacklist = [
        # synapse example config
        "127.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "192.0.0.0/24"
        "169.254.0.0/16"
        "192.88.99.0/24"
        "198.18.0.0/15"
        "192.0.2.0/24"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "::1/128"
        "fe80::/10"
        "fc00::/7"
        "2001:db8::/32"
        "ff00::/8"
        "fec0::/10"

        # NTNU
        values.ntnu.ipv4-space
        values.ntnu.ipv6-space
      ];
    };
  };

  services.redis.servers."".enable = true;

  services.pvv-matrix-well-known.server."m.server" = "matrix.pvv.ntnu.no:443";

  services.nginx.virtualHosts."matrix.pvv.ntnu.no" = lib.mkMerge [
  {
    kTLS = true;
  }
  {
    locations."/_synapse/admin" = {
      proxyPass = "http://$synapse_backend";
      extraConfig = ''
        allow 127.0.0.1;
        allow ::1;
        allow ${values.hosts.bicep.ipv4};
        allow ${values.hosts.bicep.ipv6};
        deny all;
      '';
    };
  }
  {
    locations = let
      connectionInfo = w: matrix-lib.workerConnectionResource "metrics" w;
      socketAddress = w: let c = connectionInfo w; in "${c.host}:${toString c.port}";

      metricsPath = w: "/metrics/${w.type}/${toString w.index}";
      proxyPath = w: "http://${socketAddress w}/_synapse/metrics";
    in lib.mapAttrs' (n: v: lib.nameValuePair
      (metricsPath v) {
        proxyPass = proxyPath v;
        extraConfig = ''
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      })
      cfg.workers.instances;
  }
  {
    locations."/metrics/master/1" = {
      proxyPass = "http://127.0.0.1:9000/_synapse/metrics";
      extraConfig = ''
        allow ${values.hosts.ildkule.ipv4};
        allow ${values.hosts.ildkule.ipv6};
        deny all;
      '';
    };

    locations."/metrics/" = let
      endpoints = lib.pipe cfg.workers.instances [
        (lib.mapAttrsToList (_: v: v))
        (map (w: "${w.type}/${toString w.index}"))
        (map (w: "matrix.pvv.ntnu.no/metrics/${w}"))
      ] ++ [ "matrix.pvv.ntnu.no/metrics/master/1" ];
    in {
      alias = pkgs.writeTextDir "/config.json"
        (builtins.toJSON [
          { targets = endpoints;
            labels = { };
          }]) + "/";
    };
  }];
}
