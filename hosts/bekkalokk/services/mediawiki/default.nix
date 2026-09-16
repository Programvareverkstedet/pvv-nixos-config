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
        "from=\"principal.pvv.ntnu.no,${values.hosts.principal.ipv6},${values.hosts.principal.ipv4}\""
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
      "pm.max_children" = 4;
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
        PdfHandler
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

      # Files
      $wgFileExtensions = [
        'bmp',
        'gif',
        'jpeg',
        'jpg',
        'mp3',
        'odg',
        'odp',
        'ods',
        'odt',
        'pdf',
        'png',
        'tiff',
        'webm',
        'webp',
      ];

      # Misc program paths
      $wgFFmpegLocation = '${lib.getExe pkgs.ffmpeg}';
      $wgExiftool = '${lib.getExe pkgs.exiftool}';
      $wgExiv2Command = '${lib.getExe pkgs.exiv2}';
      # See https://gist.github.com/sergejmueller/088dce028b6dd120a16e
      $wgJpegTran = '${lib.getExe' pkgs.mozjpeg "jpegtran"}';
      $wgGitBin = '${lib.getExe pkgs.git}';
      $wgDiff3 = '${lib.getExe' pkgs.diffutils "diff3"}';
      $wgDiff = '${lib.getExe' pkgs.diffutils "diff"}';

      $wgUseImageMagick = true;
      $wgImageMagickConvertCommand = '${lib.getExe pkgs.imagemagick}';

      # Debugging
      $wgShowExceptionDetails = false;
      $wgShowIPinHeader = false;

      # Offload background jobs to the external job runner service
      $wgJobRunRate = 0;

      # Enable caching for nginx
      $wgUseCdn = true;
      $wgCdnMaxAge = 3600;

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

      # EXT:PdfHandler
      $wgPdfProcessor = '${lib.getExe pkgs.ghostscript_headless}';
      $wgPdfPostProcessor = $wgImageMagickConvertCommand;
      $wgPdfInfo = '${lib.getExe' pkgs.poppler-utils "pdfinfo"}';
      $wgPdftoText = '${lib.getExe' pkgs.poppler-utils "pdftotext"}';

      # Override key from hardcoded config in nixpkgs
      $wgSecretKey = file_get_contents("${config.sops.secrets."mediawiki/secret-key".path}");
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

      # NOTE: ensure this pattern matches the upstream NixOS mediawiki module letter for letter
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/mediawiki.nix#L720
      #
      # TODO: rate limit more URLs: https://github.com/NixOS/infra/blob/3c20fcebc683c7515e8bde58256b609960047cad/terraform/wiki.tf
      "~ ^/w/(index|load|api|thumb|opensearch_desc|rest|img_auth)\\.php$" = lib.mkForce {
        extraConfig = ''
          rewrite ^/w/(.*) /$1 break;
          include ${pkgs.nginx}/conf/fastcgi.conf;
          fastcgi_index index.php;
          fastcgi_pass unix:${config.services.phpfpm.pools.mediawiki.socket};

          limit_req zone=mediawiki_scrapers burst=30 nodelay;

          fastcgi_cache mediawiki;
          fastcgi_cache_key "$scheme$request_method$host$request_uri";
          fastcgi_cache_methods GET HEAD;
          fastcgi_cache_bypass $mediawiki_cache_bypass;
          fastcgi_no_cache $mediawiki_cache_bypass;
          fastcgi_cache_valid 200 1h;
          fastcgi_cache_use_stale error timeout updating http_500 http_503;
          fastcgi_cache_background_update on;
          fastcgi_cache_lock on;
          add_header X-Cache-Status $upstream_cache_status;
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


  services.nginx.commonHttpConfig = lib.mkIf cfg.enable ''
    # mediawiki_authenticated is true if we are logged in.
    map $http_cookie $mediawiki_authenticated {
      default 0;
      "~*(?i)(session|token|userid|username)=" 1;
    }

    # mediawiki_scraper_key is empty if we are logged in.
    map $mediawiki_authenticated $mediawiki_scraper_key {
      0 $binary_remote_addr;
      1 "";
    }

    # mediawiki_cache_bypass is true we are authenticated.
    map $mediawiki_authenticated $mediawiki_cache_bypass {
      0 0;
      1 1;
    }

    limit_req_zone $mediawiki_scraper_key zone=mediawiki_scrapers:10m rate=60r/m;
    limit_req_status 429;

    fastcgi_cache_path /var/cache/nginx/mediawiki levels=1:2 keys_zone=mediawiki:20m max_size=1g inactive=1d use_temp_path=off;
  '';

  systemd.services.mediawiki-init = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    serviceConfig = {
      UMask = lib.mkForce "0007";
    };
  };

  systemd.services.phpfpm-mediawiki = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    serviceConfig = {
      UMask = lib.mkForce "0007";
    };
  };

  # https://www.mediawiki.org/wiki/Manual:Job_queue
  systemd.services.mediawiki-jobrunner = lib.mkIf cfg.enable {
    description = "MediaWiki background job runner";
    after = [ "sops-install-secrets.service" "mediawiki-init.service" ];
    requires = [ "sops-install-secrets.service" "mediawiki-init.service" ];
    wantedBy = [ "multi-user.target" ];
    environment.MEDIAWIKI_CONFIG = config.services.phpfpm.pools.mediawiki.phpEnv.MEDIAWIKI_CONFIG;
    unitConfig.JoinsNamespaceOf = [ "phpfpm-mediawiki.service" ];
    serviceConfig = {
      ExecStart = "${lib.getExe cfg.phpPackage} ${cfg.finalPackage}/share/mediawiki/maintenance/run.php runJobs.php --wait --maxjobs=20";
      User = user;
      Group = group;
      UMask = "0007";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
