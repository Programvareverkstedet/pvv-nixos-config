{ config, lib, pkgs, ... }:

let
  cfg = config.services.matrix-synapse-next;
in
{

  imports = [ ./synapse-module ];

  services.matrix-synapse-next = {
    enable = true;
    package = pkgs.matrix-synapse;

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


      enable_metrics = true;

      use_presence = true;


      password_config.enabled = lib.mkForce false;

      enable_registration = false;


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
          {
            given_name = "Drift";
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

  services.redis.servers.matrix.enable = true;

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
