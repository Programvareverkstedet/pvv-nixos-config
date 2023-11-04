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
          --replace '$SAML_TRUSTED_DOMAINS' 'array( "wiki2.pvv.ntnu.no" )' \
          --replace '$SAML_DATABASE_DSN' '"pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=mediawiki_simplesamlphp"' \
          --replace '$SAML_DATABASE_USERNAME' '"mediawiki_simplesamlphp"' \
          --replace '$SAML_DATABASE_PASSWORD' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/postgres_password".path}")' \
          --replace '$CACHE_DIRECTORY' '/var/cache/mediawiki/idp'
      '';
    };
  };
in {
  services.idp.sp-remote-metadata = [ "https://wiki2.pvv.ntnu.no/simplesaml/" ];

  sops.secrets = {
    "mediawiki/password" = {
      owner = user;
      group = group;
    };
    "mediawiki/postgres_password" = {
      owner = user;
      group = group;
    };
    "mediawiki/simplesamlphp/postgres_password" = {
      owner = user;
      group = group;
    };
    "mediawiki/simplesamlphp/cookie_salt" = {
      owner = user;
      group = group;
    };
    "mediawiki/simplesamlphp/admin_password" = {
      owner = user;
      group = group;
    };
  };

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

    # Host through nginx
    webserver = "none";
    poolConfig = let
      listenUser = config.services.nginx.user;
      listenGroup = config.services.nginx.group;
    in {
      inherit user group;
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

      # to accept *.html file
      "security.limit_extensions" = "";
    };

    extensions = {
      inherit (pkgs.mediawiki-extensions) DeleteBatch UserMerge PluggableAuth SimpleSAMLphp;
    };

    extraConfig = ''
      $wgServer = "https://wiki2.pvv.ntnu.no";
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

      # Misc. URL rules
      $wgUsePathInfo = true;
      $wgScriptExtension = ".php";
      $wgNamespacesWithSubpages[NS_MAIN] = true;

      # Styling
      $wgLogos = array(
        "2x" => "/PNG/PVV-logo.png",
        "icon" => "/PNG/PVV-logo.svg",
      );
      # wfLoadSkin('Timeless');
      $wgDefaultSkin = "vector-2022";
      # from https://github.com/wikimedia/mediawiki-skins-Vector/blob/master/skin.json
      $wgVectorDefaultSidebarVisibleForAnonymousUser = true;
      $wgVectorResponsive = true;

      # Misc
      $wgEmergencyContact = "${cfg.passwordSender}";
      $wgShowIPinHeader = false;
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

  # Override because of https://github.com/NixOS/nixpkgs/issues/183097
  systemd.services.mediawiki-init.script = let
    # According to module
    stateDir = "/var/lib/mediawiki";
    pkg = cfg.finalPackage;
    mediawikiConfig = config.services.phpfpm.pools.mediawiki.phpEnv.MEDIAWIKI_CONFIG;
    inherit (lib) optionalString mkForce;
  in mkForce ''
    if ! test -e "${stateDir}/secret.key"; then
      tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c 64 > ${stateDir}/secret.key
    fi

    echo "exit( wfGetDB( DB_MASTER )->tableExists( 'user' ) ? 1 : 0 );" | \
    ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/eval.php --conf ${mediawikiConfig} && \
    ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/install.php \
      --confpath /tmp \
      --scriptpath / \
      --dbserver "${cfg.database.host}" \
      --dbport ${toString cfg.database.port} \
      --dbname ${cfg.database.name} \
      ${optionalString (cfg.database.tablePrefix != null) "--dbprefix ${cfg.database.tablePrefix}"} \
      --dbuser ${cfg.database.user} \
      ${optionalString (cfg.database.passwordFile != null) "--dbpassfile ${cfg.database.passwordFile}"} \
      --passfile ${cfg.passwordFile} \
      --dbtype ${cfg.database.type} \
      ${cfg.name} \
      admin

    ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/update.php --conf ${mediawikiConfig} --quick
  '';

  users.groups.mediawiki.members = [ "nginx" ];

  services.nginx.virtualHosts."wiki2.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;
    root = "${config.services.mediawiki.finalPackage}/share/mediawiki";
    locations =  {
      "/" = {
	index = "index.php";
      };

      "~ /(.+\\.php)" = {
        extraConfig = ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_index index.php;
          fastcgi_pass unix:${config.services.phpfpm.pools.mediawiki.socket};
          include ${pkgs.nginx}/conf/fastcgi_params;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
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

      "/images/".alias = "${config.services.mediawiki.uploadsDir}/";

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
