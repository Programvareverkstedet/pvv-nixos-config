{ config, lib, pkgs, values, inputs, ... }:

let
  cfg = config.services.matrix-synapse-next;

  matrix-lib = inputs.matrix-next.lib;

  imap0Attrs = with lib; f: set:
    listToAttrs (imap0 (i: attr: nameValuePair attr (f i attr set.${attr})) (attrNames set));
in {
  sops.secrets."matrix/synapse/dbconfig" = {
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    key = "synapse/dbconfig";
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  sops.secrets."matrix/synapse/signing_key" = {
    key = "synapse/signing_key";
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  sops.secrets."matrix/synapse/user_registration" = {
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    key = "synapse/signing_key";
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  services.matrix-synapse-next = {
    enable = true;

    dataDir = "/data/synapse";

    workers.federationSenders = 2;
    workers.federationReceivers = 2;
    workers.initialSyncers = 1;
    workers.normalSyncers = 1;
    workers.eventPersisters = 2;
    workers.useUserDirectoryWorker = true;

    enableNginx = true;

    extraConfigFiles = [
      config.sops.secrets."matrix/synapse/dbconfig".path
      config.sops.secrets."matrix/synapse/user_registration".path
    ];

    settings = {
      server_name = "pvv.ntnu.no";
      public_baseurl = "https://matrix.pvv.ntnu.no";

      signing_key_path = config.sops.secrets."matrix/synapse/signing_key".path;

      media_store_path =  "${cfg.dataDir}/media";

      presence.enabled = false;

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

      password_config.enabled = lib.mkForce false;

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
        "129.241.0.0/16"
        "2001:700:300::/44"
      ];

      saml2_config = {
        sp_config.metadata.remote = [
          { url = "https://idp.pvv.ntnu.no/simplesaml/saml2/idp/metadata.php"; }
        ];

        description = [ "Matrix Synapse SP" "en" ];
        name = [ "Matrix Synapse SP" "en" ];

        ui_info = {
          display_name = [
            {
              lang = "en";
              text = "PVV Matrix login";
            }
          ];
          description = [
            {
              lang = "en";
              text = "Matrix is a modern free and open federated chat protocol";
            }
          ];
          #information_url = [
          #  {
          #    lang = "en";
          #    text = "";
          #  };
          #];
          #privacy_statement_url = [
          #  {
          #    lang = "en";
          #    text = "";
          #  };
          #];
          keywords = [
            {
              lang = "en";
              text = [ "Matrix" "Element" ];
            }
          ];
          #logo = [
          #  {
          #    lang = "en";
          #    text = "";
          #    width = "";
          #    height = "";
          #  }
          #];
        };

        organization = {
          name = "Programvareverkstedet";
          display_name = [ "Programvareverkstedet" "en" ];
          url = "https://www.pvv.ntnu.no";
        };
        contact_person = [
          { given_name = "Drift";
            sur_name = "King";
            email_adress = [ "drift@pvv.ntnu.no" ];
            contact_type = "technical";
          }
        ];

        user_mapping_provider = {
          config = {
            mxid_source_attribute =  "uid"; # What is this supposed to be?
            mxid_mapping = "hexencode";
          };
        };

        #attribute_requirements = [
        #  {attribute = "userGroup"; value = "medlem";} # Do we have this?
        #];
      };
    };
  };

  services.redis.servers."".enable = true;
  
  services.nginx.virtualHosts."matrix.pvv.ntnu.no" = lib.mkMerge [({
    locations = let
      connectionInfo = w: matrix-lib.workerConnectionResource "metrics" w;
      socketAddress = w: let c = connectionInfo w; in "${c.host}:${toString (c.port)}";

      metricsPath = w: "/metrics/${w.type}/${toString w.index}";
      proxyPath = w: "http://${socketAddress w}/_synapse/metrics";
    in lib.mapAttrs' (n: v: lib.nameValuePair
      (metricsPath v) ({
        proxyPass = proxyPath v;
        extraConfig = ''
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      }))
      cfg.workers.instances;
  })
  ({
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
  })];
}