{ pkgs, lib, fp, config, values, ... }: let
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
          --replace-warn '$SAML_COOKIE_SECURE' 'true' \
          --replace-warn '$SAML_COOKIE_SALT' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/cookie_salt".path}")' \
          --replace-warn '$SAML_ADMIN_NAME' '"Drift"' \
          --replace-warn '$SAML_ADMIN_EMAIL' '"drift@pvv.ntnu.no"' \
          --replace-warn '$SAML_ADMIN_PASSWORD' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/admin_password".path}")' \
          --replace-warn '$SAML_TRUSTED_DOMAINS' 'array( "wiki.pvv.ntnu.no" )' \
          --replace-warn '$SAML_DATABASE_DSN' '"pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=mediawiki_simplesamlphp"' \
          --replace-warn '$SAML_DATABASE_USERNAME' '"mediawiki_simplesamlphp"' \
          --replace-warn '$SAML_DATABASE_PASSWORD' 'file_get_contents("${config.sops.secrets."mediawiki/simplesamlphp/postgres_password".path}")' \
          --replace-warn '$CACHE_DIRECTORY' '/var/cache/mediawiki/idp'
      '';
    };
  };
in {
  services.idp.sp-remote-metadata = [ "https://wiki.pvv.ntnu.no/simplesaml/" ];

  sops.secrets = lib.pipe [
    "mediawiki/secret-key"
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

  services.rsync-pull-targets = {
    enable = true;
    locations.${cfg.uploadsDir} = {
      user = "root";
      rrsyncArgs.ro = true;
      authorizedKeysAttrs = [
        "restrict"
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICHFHa3Iq1oKPhbKCAIHgOoWOTkLmIc7yqxeTbut7ig/ mediawiki rsync backup";
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
      inherit (pkgs.mediawiki-extensions)
        CodeEditor
        CodeMirror
        DeleteBatch
        PluggableAuth
        Popups
        Scribunto
        SimpleSAMLphp
        TemplateData
        TemplateStyles
        UserMerge
        VisualEditor
        WikiEditor
        ;
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

      # Experimental dark mode support for Vector 2022
      $wgVectorNightMode['beta'] = true;
      $wgVectorNightMode['logged_out'] = true;
      $wgVectorNightMode['logged_in'] = true;
      $wgDefaultUserOptions['vector-theme'] = 'os';

      # Misc
      $wgEmergencyContact = "${cfg.passwordSender}";
      $wgUseTeX = false;
      $wgLocalInterwiki = $wgSitename;
      # Fix https://github.com/NixOS/nixpkgs/issues/183097
      $wgDBserver = "${toString cfg.database.host}";
      $wgAllowCopyUploads = true;

      # Misc program paths
      $wgFFmpegLocation = '${pkgs.ffmpeg}/bin/ffmpeg';
      $wgExiftool = '${pkgs.exiftool}/bin/exiftool';
      $wgExiv2Command = '${pkgs.exiv2}/bin/exiv2';
      # See https://gist.github.com/sergejmueller/088dce028b6dd120a16e
      $wgJpegTran = '${pkgs.mozjpeg}/bin/jpegtran';
      $wgGitBin = '${pkgs.git}/bin/git';

      # Debugging
      $wgShowExceptionDetails = false;
      $wgShowIPinHeader = false;

      # EXT:{SimpleSAML,PluggableAuth}
      $wgSimpleSAMLphp_InstallDir = "${simplesamlphp}/share/php/simplesamlphp/";
      $wgPluggableAuth_Config['Log in using SAML'] = [
        'plugin' => 'SimpleSAMLphp',
        'data' => [
          'authSourceId' => 'default-sp',
          'usernameAttribute' => 'uid',
          'emailAttribute' => 'mail',
          'realNameAttribute' => 'cn',
        ]
      ];

      # EXT:Scribunto
      $wgScribuntoDefaultEngine = 'luastandalone';
      $wgScribuntoEngineConf['luastandalone']['luaPath'] = '${pkgs.lua}/bin';

      # EXT:WikiEditor
      $wgWikiEditorRealtimePreview = true;
    '';
  };

  # Cache directory for simplesamlphp
  # systemd.services.phpfpm-mediawiki.serviceConfig.CacheDirectory = "mediawiki/simplesamlphp";
  systemd.tmpfiles.settings."10-mediawiki"."/var/cache/mediawiki/simplesamlphp".d = lib.mkIf cfg.enable {
    user = "mediawiki";
    group = "mediawiki";
    mode = "0770";
  };

  users.groups.mediawiki.members = lib.mkIf cfg.enable [ "nginx" ];

  services.nginx.virtualHosts."wiki.pvv.ntnu.no" = lib.mkIf cfg.enable {
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

      "= /PNG/PVV-logo.svg".alias = fp /assets/logo_blue_regular.svg;
      "= /PNG/PVV-logo.png".alias = fp /assets/logo_blue_regular.png;
      "= /favicon.ico".alias = pkgs.runCommandLocal "mediawiki-favicon.ico" {
        buildInputs = with pkgs; [ imagemagick ];
      } ''
        magick \
          ${fp /assets/logo_blue_regular.png} \
          -resize x64 \
          -gravity center \
          -crop 64x64+0+0 \
          -flatten \
          -colors 256 \
          -background transparent \
          $out
      '';
    };

  };

  systemd.services.mediawiki-init = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      BindReadOnlyPaths = [ "/run/credentials/mediawiki-init.service/secret-key:/var/lib/mediawiki/secret.key" ];
      LoadCredential = [ "secret-key:${config.sops.secrets."mediawiki/secret-key".path}" ];
    };
  };

  systemd.services.phpfpm-mediawiki = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      BindReadOnlyPaths = [ "/run/credentials/phpfpm-mediawiki.service/secret-key:/var/lib/mediawiki/secret.key" ];
      LoadCredential = [ "secret-key:${config.sops.secrets."mediawiki/secret-key".path}" ];
    };
  };
}
