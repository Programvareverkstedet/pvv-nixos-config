{ pkgs, lib, config, values, pkgs-unstable, ... }: let
  cfg = config.services.mediawiki;

  # "mediawiki"
  user = config.systemd.services.mediawiki-init.serviceConfig.User;

  # "mediawiki"
  group = config.users.users.${user}.group;

  simplesamlphp = pkgs.simplesamlphp.override {
    extra_files = {
      "metadata/saml20-idp-remote.php" = pkgs.writeText "mediawiki-saml20-idp-remote.php" (import ../idp-simplesamlphp/metadata.php.nix);

      "config/authsources.php" = ./simplesaml-authsources.php;

      "config/config.php" = pkgs.runCommandLocal "mediawiki-simplesamlphp-config.php" { } ''
        cp ${./simplesaml-config.php} "$out"

        substituteInPlace "$out" \
          --replace '$SAML_COOKIE_SECURE' 'true' \
          --replace '$SAML_COOKIE_SALT' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/cookie_salt".path}")' \
          --replace '$SAML_ADMIN_NAME' '"Drift"' \
          --replace '$SAML_ADMIN_EMAIL' '"drift@pvv.ntnu.no"' \
          --replace '$SAML_ADMIN_PASSWORD' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/admin_password".path}")' \
          --replace '$SAML_TRUSTED_DOMAINS' 'array( "wiki.pvv.ntnu.no" )' \
          --replace '$SAML_DATABASE_DSN' '"pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=mediawiki_simplesamlphp"' \
          --replace '$SAML_DATABASE_USERNAME' '"mediawiki_simplesamlphp"' \
          --replace '$SAML_DATABASE_PASSWORD' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/postgres_password".path}")' \
          --replace '$CACHE_DIRECTORY' '/var/cache/mediawiki/idp'
      '';
    };
  };
in {
  services.idp.sp-remote-metadata = [ "https://wiki.pvv.ntnu.no/simplesaml/" ];

  sops.secrets = lib.pipe [
    "mediawiki/password"
    "mediawiki/postgres_password"
    "mediawiki/simplesamlphp/postgres_password"
    "mediawiki/simplesamlphp/cookie_salt"
    "mediawiki/simplesamlphp/admin_password"
  ] [
    (map (key: lib.nameValuePair key {
      owner = user;
      group = group;
      restartUnits = [ "phpfpm-mediawiki.service" ];
    }))
    lib.listToAttrs
  ];

  services.mediawiki = {
    enable = true;
    name = "Programvareverkstedet";
    passwordFile = config.sops.secrets."mediawiki/password".path;
    passwordSender = "drift@pvv.ntnu.no";

    database = {
      type = "mysql";
      host = "mysql.pvv.ntnu.no";
      port = 3306;
      user = "mediawiki";
      passwordFile = config.sops.secrets."mediawiki/postgres_password".path;
      createLocally = false;
      # TODO: create a normal database and copy over old data when the service is production ready
      name = "mediawiki";
    };

    webserver = "nginx";
    nginx.hostName = "wiki.pvv.ntnu.no";

    poolConfig = {
      inherit user group;
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;

      "catch_workers_output" = true;
      "php_admin_flag[log_errors]" = true;
      # "php_admin_value[error_log]" = "stderr";

      # to accept *.html file
      "security.limit_extensions" = "";
    };

    extensions = {
      #inherit (pkgs.mediawiki-extensions) DeleteBatch UserMerge PluggableAuth SimpleSAMLphp VisualEditor;
      inherit (pkgs.mediawiki-extensions) UserMerge PluggableAuth SimpleSAMLphp VisualEditor;
    };

    extraConfig = ''
      $wgServer = "https://wiki.pvv.ntnu.no";
      $wgLocaltimezone = "Europe/Oslo";

      # Only allow login through SSO
      $wgEnableEmail = false;
      $wgEnableUserEmail = false;
      $wgEmailAuthentication = false;
      $wgGroupPermissions['*']['createaccount'] = false;
      $wgGroupPermissions['*']['autocreateaccount'] = true;
      $wgPluggableAuth_EnableAutoLogin = false;

      # Misc. permissions
      $wgGroupPermissions['*']['edit'] = false;
      $wgGroupPermissions['*']['read'] = true;

      # Allow subdirectories in article URLs
      $wgNamespacesWithSubpages[NS_MAIN] = true;

      # Styling
      $wgLogos = array(
        "2x" => "/PNG/PVV-logo.png",
        "icon" => "/PNG/PVV-logo.svg",
      );
      $wgDefaultSkin = "vector-2022";
      # from https://github.com/wikimedia/mediawiki-skins-Vector/blob/master/skin.json
      $wgVectorDefaultSidebarVisibleForAnonymousUser = true;
      $wgVectorResponsive = true;

      # Misc
      $wgEmergencyContact = "${cfg.passwordSender}";
      $wgUseTeX = false;
      $wgLocalInterwiki = $wgSitename;

      # SimpleSAML
      $wgSimpleSAMLphp_InstallDir = "${simplesamlphp}/share/php/simplesamlphp/";
      $wgPluggableAuth_Config['Log in using my SAML'] = [
        'plugin' => 'SimpleSAMLphp',
        'data' => [
          'authSourceId' => 'default-sp',
          'usernameAttribute' => 'uid',
          'emailAttribute' => 'mail',
          'realNameAttribute' => 'cn',
        ]
      ];

      # Debugging
      $wgShowExceptionDetails = false;
      $wgShowIPinHeader = false;

      # Fix https://github.com/NixOS/nixpkgs/issues/183097
      $wgDBserver = "${toString cfg.database.host}";
    '';
  };

  # Cache directory for simplesamlphp
  # systemd.services.phpfpm-mediawiki.serviceConfig.CacheDirectory = "mediawiki/simplesamlphp";
  systemd.tmpfiles.settings."10-mediawiki"."/var/cache/mediawiki/simplesamlphp".d = {
    user = "mediawiki";
    group = "mediawiki";
    mode = "0770";
  };

  users.groups.mediawiki.members = [ "nginx" ];

  services.nginx.virtualHosts."wiki.pvv.ntnu.no" = {
    kTLS = true;
    forceSSL = true;
    enableACME = true;
    locations =  {
      "= /wiki/Main_Page" = lib.mkForce {
        return = "301 /wiki/Programvareverkstedet";
      };

      # based on https://simplesamlphp.org/docs/stable/simplesamlphp-install.html#configuring-nginx
      "^~ /simplesaml/" = {
        alias = "${simplesamlphp}/share/php/simplesamlphp/public/";
        index = "index.php";

        extraConfig = ''
          location ~ ^/simplesaml/(?<phpfile>.+?\.php)(?<pathinfo>/.*)?$ {
            include ${pkgs.nginx}/conf/fastcgi_params;
            fastcgi_pass unix:${config.services.phpfpm.pools.mediawiki.socket}; 
            fastcgi_param SCRIPT_FILENAME ${simplesamlphp}/share/php/simplesamlphp/public/$phpfile;

            # Must be prepended with the baseurlpath
            fastcgi_param SCRIPT_NAME /simplesaml/$phpfile;

            fastcgi_param PATH_INFO $pathinfo if_not_empty;
          }
        '';
      };

      "= /PNG/PVV-logo.svg".alias = ../../../../assets/logo_blue_regular.svg;
      "= /PNG/PVV-logo.png".alias = ../../../../assets/logo_blue_regular.png;
      "= /favicon.ico".alias = pkgs.runCommandLocal "mediawiki-favicon.ico" {
        buildInputs = with pkgs; [ imagemagick ];
      } ''
        convert \
          -resize x64 \
          -gravity center \
          -crop 64x64+0+0 \
          ${../../../../assets/logo_blue_regular.png} \
          -flatten \
          -colors 256 \
          -background transparent \
          $out
      '';
    };

  };
}
