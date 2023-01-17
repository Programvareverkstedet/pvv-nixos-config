{ config, lib, pkgs, values, ... }:

let
  cfg = config.services.matrix-synapse-next;

  imap0Attrs = with lib; f: set:
    listToAttrs (imap0 (i: attr: nameValuePair attr (f i attr set.${attr})) (attrNames set));
in {
  sops.secrets."matrix/synapse/dbconfig" = {
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  sops.secrets."matrix/synapse/signing_key" = {
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };

  services.matrix-synapse-next = {
    enable = true;

    dataDir = "/data/synapse";

    workers.federationSenders = 2;
    workers.federationReceivers = 1;
    workers.initialSyncers = 1;
    workers.normalSyncers = 1;
    workers.eventPersisters = 1;
    workers.useUserDirectoryWorker = true;

    enableNginx = true;

    extraConfigFiles = [
      config.sops.secrets."matrix/synapse/dbconfig".path
    ];

    settings = {
      server_name = "pvv.ntnu.no";
      public_baseurl = "https://matrix.pvv.ntnu.no";

      signing_key_path = config.sops.secrets."matrix/synapse/signing_key".path;

      media_store_path =  "${cfg.dataDir}/media";

      autocreate_auto_join_rooms = false;
      auto_join_rooms = [
        "#pvv:pvv.ntnu.no" # Main space
        "#announcements:pvv.ntnu.no"
        "#general:pvv.ntnu.no"
      ];

      allow_public_rooms_over_federation = true;

      max_upload_size = "150M";

      enable_metrics = true;

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
      isListenerType = type: listener: lib.lists.any (r: lib.lists.any (n: n == type) r.names) listener.resources;
      isMetricsListener = l: isListenerType "metrics" l;

      firstMetricsListener = w: lib.lists.findFirst isMetricsListener (throw "No metrics endpoint on worker") w.settings.worker_listeners;

      wAddress = w: lib.lists.findFirst (_: true) (throw "No address in receiver") (firstMetricsListener w).bind_addresses;
      wPort = w: (firstMetricsListener w).port;

      socketAddress = w: "${wAddress w}:${toString (wPort w)}";

      metricsPath = w: "/metrics/${w.type}/${toString w.index}";
      proxyPath = w: "http://${socketAddress w}/_synapse/metrics";
    in lib.mapAttrs' (n: v: lib.nameValuePair (metricsPath v) ({ proxyPass = proxyPath v; }))
      cfg.workers.instances;
  })
  ({
    locations."/metrics/master/1" = {
      proxyPass = "http://127.0.0.1:9000/_synapse/metrics";
      extraConfig = ''
        allow ${values.ildkule.ipv4};
        deny all;
      '';
    };

    locations."/metrics/" = let
      endpoints = builtins.map (x: "matrix.pvv.ntnu.no/metrics/${x}") [
        "master/1"
        "fed-sender/1"
        "fed-sender/2"
        "fed-receiver/1"
        "initial-sync/1"
        "normal-sync/1"
        "event-persist/1"
        "user-dir/1"
      ];
    in {
      alias = pkgs.writeTextDir "/config.json"
        (builtins.toJSON [
          { targets = endpoints;
            labels = { };
          }]) + "/";
      extraConfig = ''
        allow ${values.ildkule.ipv4};
        deny all;
      '';
    };
  })];
}
