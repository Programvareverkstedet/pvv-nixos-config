{ config, pkgs, lib, ... }:
let
  pwAuthScript = pkgs.writeShellApplication {
    name = "pwauth";
    runtimeInputs = with pkgs; [ coreutils heimdal ];
    text = ''
      read -r user1
      user2="$(echo -n "$user1" | tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz')"
      if test "$user1" != "$user2"
      then
        read -r _
        exit 2
      fi
      kinit --password-file=STDIN "''${user1}@PVV.NTNU.NO" >/dev/null 2>/dev/null
      kdestroy >/dev/null 2>/dev/null
    '';
  };

  package = pkgs.simplesamlphp.override {
    extra_files = {
      "modules/authpwauth/src/Auth/Source/PwAuth.php" = ./authpwauth.php;
    };
  };

  metadataDir = pkgs.linkFarm "idp-simplesamlphp-metadata" {
    # NOTE: Using self signed certificate created 30. march 2024, with command:
    # openssl req -newkey rsa:4096 -new -x509 -days 365 -nodes -out idp.crt -keyout idp.pem
    "saml20-idp-hosted.php" = pkgs.writeText "saml20-idp-remote.php" ''
      <?php
      $metadata['https://idp.pvv.ntnu.no/'] = array(
        'host' => '__DEFAULT__',
        'privatekey' => '${config.sops.secrets."idp/privatekey".path}',
        'certificate' => '${./idp.crt}',
        'auth' => 'pwauth',
      );
      ?>
    '';

    "saml20-sp-remote.php" = pkgs.writeText "saml20-sp-remote.php" ''
      <?php
        ${ lib.pipe config.services.idp.sp-remote-metadata [
          (map (url: ''
            $metadata['${url}'] = [
              'SingleLogoutService' => [
                [
                  'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
                  'Location' => '${url}module.php/saml/sp/saml2-logout.php/default-sp',
                ],
                [
                  'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:SOAP',
                  'Location' => '${url}module.php/saml/sp/saml2-logout.php/default-sp',
                ],
              ],
              'AssertionConsumerService' => [
                [
                  'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
                  'Location' => '${url}module.php/saml/sp/saml2-acs.php/default-sp',
                  'index' => 0,
                ],
                [
                  'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact',
                  'Location' => '${url}module.php/saml/sp/saml2-acs.php/default-sp',
                  'index' => 1,
                ],
              ],
            ];
          ''))
          (lib.concatStringsSep "\n")
        ]}
      ?>
    '';
  };

  authsources = pkgs.writeText "idp-authsources.php" ''
    <?php
      $config = array(
        'admin' => array(
          'core:AdminPassword'
        ),
        'pwauth' => array(
          'authpwauth:PwAuth',
          'pwauth_bin_path' => '${lib.getExe pwAuthScript}',
          'mail_domain' => '@pvv.ntnu.no',
        ),
      );
    ?>
  '';

  configOverrides = let
    inherit ((pkgs.formats.php { }).lib) mkRaw;
    readSecret = name: "file_get_contents('${config.sops.secrets.${name}.path}')";
  in (pkgs.formats.php { }).generate "idp-simplesamlphp-config.php" {
    "baseurlpath" = "/";
    "cachedir" = "/var/cache/idp";
    "metadatadir" = "${metadataDir}";

    "technicalcontact_name" = "Drift";
    "technicalcontact_email" = "drift@pvv.ntnu.no";

    "secretsalt" = mkRaw (readSecret "idp/cookie_salt");
    "auth.adminpassword" = mkRaw (readSecret "idp/admin_password");

    "trusted.url.domains" = [ "idp.pvv.ntnu.no" ];

    "database.dsn" = "pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=idp";
    "database.username" = "idp";
    "database.password" = mkRaw (readSecret "idp/postgres_password");
    "database.persistent" = true;

    "enable.saml20-idp" = true;

    "module.enable" = {
      "admin" = true;
      "authpwauth" = true;
    };

    "session.state.timeout" = 10 * 60;
    "session.cookie.secure" = true;

    "store.type" = "memcache";
    "store.sql.dsn" = "pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=idp";
    "store.sql.username" = "idp";
    "store.sql.password" = mkRaw (readSecret "idp/postgres_password");
    "memcache_store.servers" = {
      "idp" = [
        { "hostname" = "/run/memcached/memcached.sock"; }
      ];
    };

    "assets" = {
      "caching" = {
        "max_age" = 86400;
        "etag" = false;
      };
    };
  };
in
{
  options.services.idp.sp-remote-metadata = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    description = ''
      List of urls point to (simplesamlphp) service profiders, which the idp should trust.

      :::{.note}
      Make sure the url ends with a `/`
      :::
    '';
  };

  config = {
    sops.secrets = {
      "idp/privatekey" = {
        owner = "idp";
        group = "idp";
        mode = "0770";
      };
      "idp/admin_password" = {
        owner = "idp";
        group = "idp";
      };
      "idp/postgres_password" = {
        owner = "idp";
        group = "idp";
      };
      "idp/cookie_salt" = {
        owner = "idp";
        group = "idp";
      };
    };

    users.groups."idp" = { };
    users.users."idp" = {
      description = "PVV Identity Provider Service User";
      group = "idp";
      createHome = false;
      isSystemUser = true;
    };

    systemd.tmpfiles.settings."10-idp" = {
      "/var/cache/idp".d = {
        user = "idp";
        group = "idp";
        mode = "0770";
      };
      "/var/lib/idp".d = {
        user = "idp";
        group = "idp";
        mode = "0770";
      };
    };

    services.memcached = {
      enable = true;
      enableUnixSocket = true;
      user = "idp";
      maxMemory = 256;
    };

    services.phpfpm.pools.idp = {
      user = "idp";
      group = "idp";
      phpEnv = {
        SIMPLESAMLPHP_CONFIG_OVERRIDES_FILE = "${configOverrides}";
        SIMPLESAMLPHP_AUTHSOURCES_FILE = "${authsources}";
      };
      phpPackage = pkgs.php.withExtensions ({ enabled, all }: enabled ++ [ all.memcached ]);
      settings = let
        listenUser = config.services.nginx.user;
        listenGroup = config.services.nginx.group;
      in {
        "pm" = "dynamic";
        "pm.max_children" = 8;
        "pm.max_requests" = 5000;
        "request_terminate_timeout" = "30s";
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "listen.owner" = listenUser;
        "listen.group" = listenGroup;

        "catch_workers_output" = true;
        "php_admin_flag[log_errors]" = true;
        # "php_admin_value[error_log]" = "stderr";
      };
    };

    systemd.services."phpfpm-idp" = {
      after = [ "sops-install-secrets.service" "memcached.service" ];
      requires = [ "sops-install-secrets.service" ];
      wants = [ "memcached.service" ];
    };

    services.nginx.appendHttpConfig = ''
      limit_req_zone $cookie_SimpleSAMLSessionID zone=idp_session:10m rate=30r/m;
    '';

    services.nginx.virtualHosts."idp.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;
      kTLS = true;
      root = "${package}/share/php/simplesamlphp/public";
      locations =  {
        # based on https://simplesamlphp.org/docs/stable/simplesamlphp-install.html#configuring-nginx
        "/" = {
          alias = "${package}/share/php/simplesamlphp/public/";
          index = "index.php";

          extraConfig = ''
            location ~ ^/(?<phpfile>.+?\.php)(?<pathinfo>/.*)?$ {
              limit_req zone=idp_session burst=10 nodelay;
              limit_req_status 429;

              include ${pkgs.nginx}/conf/fastcgi_params;
              fastcgi_pass unix:${config.services.phpfpm.pools.idp.socket};
              fastcgi_param SCRIPT_FILENAME ${package}/share/php/simplesamlphp/public/$phpfile;
              fastcgi_param SCRIPT_NAME /$phpfile;
              fastcgi_param PATH_INFO $pathinfo if_not_empty;
            }
          '';
        };
        "^~ /simplesaml/".extraConfig = ''
          rewrite ^/simplesaml/(.*)$ /$1 redirect;
          return 404;
        '';
        "/robots.txt" = {
          root = pkgs.writeTextDir "robots.txt" ''
            User-agent: *
            Disallow: /
          '';
        };
      };
    };
  };
}
