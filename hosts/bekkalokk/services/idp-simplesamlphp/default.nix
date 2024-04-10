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
      # NOTE: Using self signed certificate created 30. march 2024, with command:
      # openssl req -newkey rsa:4096 -new -x509 -days 365 -nodes -out idp.crt -keyout idp.pem
      "metadata/saml20-idp-hosted.php" = pkgs.writeText "saml20-idp-remote.php" ''
        <?php
	  $metadata['https://idp.pvv.ntnu.no/'] = array(
	    'host' => '__DEFAULT__',
	    'privatekey' => '${config.sops.secrets."idp/privatekey".path}',
	    'certificate' => '${./idp.crt}',
	    'auth' => 'pwauth',
	  );
	?>
      '';

      "metadata/saml20-sp-remote.php" = pkgs.writeText "saml20-sp-remote.php" ''
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

      "config/authsources.php" = pkgs.writeText "idp-authsources.php" ''
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

      "config/config.php" = pkgs.runCommandLocal "simplesamlphp-config.php" { } ''
        cp ${./config.php} "$out"

        substituteInPlace "$out" \
          --replace '$SAML_COOKIE_SECURE' 'true' \
          --replace '$SAML_COOKIE_SALT' 'file_get_contents("${config.sops.secrets."idp/cookie_salt".path}")' \
          --replace '$SAML_ADMIN_NAME' '"Drift"' \
          --replace '$SAML_ADMIN_EMAIL' '"drift@pvv.ntnu.no"' \
          --replace '$SAML_ADMIN_PASSWORD' 'file_get_contents("${config.sops.secrets."idp/admin_password".path}")' \
          --replace '$SAML_TRUSTED_DOMAINS' 'array( "idp.pvv.ntnu.no" )' \
          --replace '$SAML_DATABASE_DSN' '"pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=idp"' \
          --replace '$SAML_DATABASE_USERNAME' '"idp"' \
          --replace '$SAML_DATABASE_PASSWORD' 'file_get_contents("${config.sops.secrets."idp/postgres_password".path}")' \
          --replace '$CACHE_DIRECTORY' '/var/cache/idp'
      '';

      "modules/authpwauth/src/Auth/Source/PwAuth.php" = ./authpwauth.php;
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

    services.phpfpm.pools.idp = {
      user = "idp";
      group = "idp";
      settings = let
        listenUser = config.services.nginx.user;
        listenGroup = config.services.nginx.group;
      in {
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.max_requests" = 500;
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
              include ${pkgs.nginx}/conf/fastcgi_params;
              fastcgi_pass unix:${config.services.phpfpm.pools.idp.socket};
              fastcgi_param SCRIPT_FILENAME ${package}/share/php/simplesamlphp/public/$phpfile;
              fastcgi_param SCRIPT_NAME /$phpfile;
              fastcgi_param PATH_INFO $pathinfo if_not_empty;
            }
          '';
        };
      };
    };
  };
}
