{ config, pkgs, ... }:

let
  cfg = config.services.matrix-synapse-next;
in
{

  imports = [ ./synapse-module ];

  services.matrix-synapse-next = {
    enable = true;
    package = pkgs.unstable.matrix-synapse; # Can be stable after 21.11?

    dataDir = "/data/synapse";

    enableMainSynapse = true;

    settings = {
      server_name = "pvv.ntnu.no";
      public_baseurl = "https://matrix.pvv.ntnu.no";

# LOL postgres too old
#      database = {
#        name = "psycopg2"; #postgres pvv ntnu no 5432
#        args = {
#          host = "postgres.pvv.ntnu.no";
#          user = "synapse";
#          password = "FOLINghtSonj";
#          dbname = "synapse";
#        };
#      };

      database = {
        name = "psycopg2";
        args = {
          host = "localhost";
          user = "synapse";
          password = "synapse";
          dbname = "synapse";
        };
      };

      listeners = [
        {
          bind_addresses = ["127.0.1.2"]; port = 8008; tls = false; type = "http";
          x_forwarded = true;
          resources = [
            { names = ["client"]; compress = true;}
            { names = ["federation"]; compress = false;}
          ];
        }
        {
          bind_addresses = ["127.0.1.2"]; port = 8010; tls = false; type = "http";
          resources = [
            { names = ["metrics"]; compress = false; }
          ];
        }
        {
          bind_addresses = [ "127.0.1.2"]; port = 9008; tls = false; type = "http";
          resources = [
           { names = ["replication"]; compress = false; }
          ];
        }
      ];

      enable_registration = true;

      enable_metrics = true;

      use_presence = true;

      signing_key_path = "${cfg.dataDir}/homeserver.signing.key";
      media_store_path =  "${cfg.dataDir}/media";

      federation_sender_instances = [
        "federation_sender1"
      ];

      redis = {
        enabled = true;
      };
    };

    workers = {
      "federation_sender1" = {
        settings = {
          worker_app = "synapse.app.federation_sender";
          worker_replication_host = "127.0.1.2";
          worker_replication_http_port = 9008;

          worker_listeners = [
            {
              bind_addresses = ["127.0.1.10"]; port = 8010; tls = false; type = "http";
              resources = [
                { names = ["metrics"]; compress = false; }
              ];
            }
          ];
        };
      };
      "federation_reciever1" = {
        settings = {
          worker_app = "synapse.app.generic_worker";
          worker_replication_host = "127.0.1.2";
          worker_replication_http_port = 9008;
   
          worker_listeners = [
            {
              bind_addresses = ["127.0.1.11"]; port = 8010; tls = false; type = "http";
              resources = [
                { names = ["metrics"]; compress = false; }
              ];
            }
            {
              bind_addresses = ["127.0.1.11"]; port = 8011; tls = false; type = "http";
              resources = [
                { names = ["federation"]; compress = false; }
              ];
            }
          ];
        };
      };
    };      
  };

  services.redis.enable = true;

  services.nginx.virtualHosts."matrix.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.1.2:8008";
    };
    locations."/_matrix/federation" = {
      proxyPass = "http://127.0.1.11:8011";
    };
  };
}
