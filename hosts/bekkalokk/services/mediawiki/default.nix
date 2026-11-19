{ pkgs, lib, fp, config, values, ... }: let
  cfg = config.services.mediawiki;

  # "mediawiki"
  user = config.systemd.services.mediawiki-init.serviceConfig.User;

  # "mediawiki"
  group = config.users.users.${user}.group;

  simplesamlphp = pkgs.simplesamlphp;

  memcachedSocket = "/run/memcached-mediawiki/memcached.sock";

  simplesamlphpMetadataDir = pkgs.linkFarm "mediawiki-simplesamlphp-metadata" {
    "saml20-idp-remote.php" = (pkgs.formats.php { finalVariable = "metadata"; }).generate "mediawiki-saml20-idp-remote.php" (import ../idp-simplesamlphp/idp-remote-metadata.nix);
  };

  simplesamlphpConfigOverrides = let
    inherit ((pkgs.formats.php { }).lib) mkRaw;
    readSecret = name: "file_get_contents('${config.sops.secrets.${name}.path}')";
    dsn = "pgsql:host=postgres.pvv.ntnu.no;port=5432;dbname=mediawiki_simplesamlphp";
    dbUser = "mediawiki_simplesamlphp";
    dbPassword = mkRaw (readSecret "mediawiki/simplesamlphp/postgres_password");
  in (pkgs.formats.php { }).generate "mediawiki-simplesamlphp-config.php" {
    "admin.checkforupdates" = false;

    "cachedir" = "/var/cache/mediawiki/idp";
    "metadatadir" = "${simplesamlphpMetadataDir}";

    "technicalcontact_name" = "Drift";
    "technicalcontact_email" = "drift@pvv.ntnu.no";

    "secretsalt" = mkRaw (readSecret "mediawiki/simplesamlphp/cookie_salt");
    "auth.adminpassword" = mkRaw (readSecret "mediawiki/simplesamlphp/admin_password");

    "trusted.url.domains" = [ "wiki.pvv.ntnu.no" ];

    "logging.processname" = "simplesamlphp-mediawiki";

    "database.dsn" = dsn;
    "database.username" = dbUser;
    "database.password" = dbPassword;

    "module.enable" = {
      "admin" = true;
    };

    "session.cookie.secure" = true;

    "session.cookie.samesite" = "Lax";
    "language.cookie.samesite" = "Lax";

    "store.type" = "memcache";
    "memcache_store.servers" = {
      "mediawiki" = [
        { "hostname" = memcachedSocket; }
      ];
    };

    "assets" = {
      "salt" = mkRaw "hash_hmac('sha256', 'assets.salt', ${readSecret "mediawiki/simplesamlphp/cookie_salt"})";
      "caching" = {
        "max_age" = 86400;
        "etag" = false;
      };
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
    phpPackage = pkgs.php.withExtensions ({ enabled, all }: enabled ++ [ all.memcached ]);
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

      # Bundled with the mediawiki source code.
      Cite = null;
      SyntaxHighlight_GeSHi = null;
    };

    extraConfig = ''
      $wgServer = "https://wiki.pvv.ntnu.no";
      $wgLocaltimezone = "Europe/Oslo";

      $wgCookieSameSite = "Lax";

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
      $wgDebugLogGroups['exception'] = 'php://stderr';
      $wgDebugLogGroups['fatal'] = 'php://stderr';

      # Offload background jobs to the external job runner service
      $wgJobRunRate = 0;

      # Store sessions in memcached so they survive php-fpm restarts
      $wgMemCachedServers = [ "${memcachedSocket}" ];
      $wgSessionCacheType = 'memcached-pecl';
      $wgObjectCacheSessionExpiry = 7 * 24 * 60 * 60; # 7 days

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

      # EXT:SyntaxHighlight_GeSHi
      $wgPygmentizePath = '${lib.getExe pkgs.python3Packages.pygments}';

      # EXT:Cite
      $wgCiteResponsiveReferences = true;

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
      0 $binary_remote_subnet;
      1 "";
    }

    # mediawiki_cache_bypass is true we are authenticated.
    map $mediawiki_authenticated $mediawiki_cache_bypass {
      0 0;
      1 1;
    }

    fastcgi_cache_path /var/cache/nginx/mediawiki levels=1:2 keys_zone=mediawiki:20m max_size=1g inactive=1d use_temp_path=off;
  '';

  services.nginx.rateLimitZones.mediawiki_scrapers = {
    key = "$mediawiki_scraper_key";
    size = "10m";
    rate = "60r/m";
  };

  systemd.services.mediawiki-init = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    serviceConfig = {
      UMask = lib.mkForce "0007";
    };
  };

  services.phpfpm.pools.mediawiki.phpEnv = lib.mkIf cfg.enable {
    SIMPLESAMLPHP_CONFIG_OVERRIDES_FILE = "${simplesamlphpConfigOverrides}";
    SIMPLESAMLPHP_AUTHSOURCES_FILE = "${./simplesaml-authsources.php}";
  };

  systemd.services.phpfpm-mediawiki = lib.mkIf cfg.enable {
    after = [
      "sops-install-secrets.service"
      "memcached-mediawiki.service"
    ];
    requires = [
      "sops-install-secrets.service"
      "memcached-mediawiki.service"
    ];
    serviceConfig = {
      UMask = lib.mkForce "0007";
    };
  };

  systemd.services.memcached-mediawiki = lib.mkIf cfg.enable {
    description = "Memcached server for mediawiki and its simplesamlphp";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.memcached} ${lib.cli.toCommandLineShellGNU { } {
        unix-socket = memcachedSocket;
        unix-mask = "0700";
        memory-limit = 64;
      }}";
      User = user;
      Group = group;
      RuntimeDirectory = "memcached-mediawiki";
      RuntimeDirectoryMode = "0700";

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictRealtime = true;
      PrivateMounts = true;
      MemoryDenyWriteExecute = true;
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
