{
  config,
  values,
  lib,
  pkgs,
  unstablePkgs,
  ...
}:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort = 2222;
in
{
  imports = [
    ./customization
    ./gpg.nix
    ./import-users
    ./web-secret-provider
  ];

  sops.secrets =
    let
      defaultConfig = {
        owner = "gitea";
        group = "gitea";
        restartUnits = [ "gitea.service" ];
      };
    in
    {
      "gitea/database" = defaultConfig;
      "gitea/email-password" = defaultConfig;
      "gitea/lfs-jwt-secret" = defaultConfig;
      "gitea/oauth2-jwt-secret" = defaultConfig;
      "gitea/secret-key" = defaultConfig;
    };

  services.gitea = {
    enable = true;
    appName = "PVV Git";

    package = unstablePkgs.gitea;

    database = {
      type = "postgres";
      host = "postgres.pvv.ntnu.no";
      port = config.services.postgresql.settings.port;
      passwordFile = config.sops.secrets."gitea/database".path;
      createDatabase = false;
    };

    mailerPasswordFile = config.sops.secrets."gitea/email-password".path;

    # https://docs.gitea.com/administration/config-cheat-sheet
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        PROTOCOL = "http+unix";
        SSH_PORT = sshPort;
        LANDING_PAGE = "explore";
        START_SSH_SERVER = true;
        START_LFS_SERVER = true;
        LFS_JWT_SECRET = lib.mkForce "";
        LFS_JWT_SECRET_URI = "file:${config.sops.secrets."gitea/lfs-jwt-secret".path}";
      };
      oauth2 = {
        JWT_SECRET = lib.mkForce "";
        JWT_SECRET_URI = "file:${config.sops.secrets."gitea/oauth2-jwt-secret".path}";
      };
      "git.timeout" = {
        MIGRATE = 3600;
        MIRROR = 1800;
      };
      mailer = {
        ENABLED = true;
        FROM = "gitea@pvv.ntnu.no";
        PROTOCOL = "smtp";
        SMTP_ADDR = "smtp.pvv.ntnu.no";
        SMTP_PORT = 587;
        USER = "gitea@pvv.ntnu.no";
        SUBJECT_PREFIX = "[pvv-git]";
      };
      metrics = {
        ENABLED = true;
        ENABLED_ISSUE_BY_LABEL = true;
        ENABLED_ISSUE_BY_REPOSITORY = true;
      };
      indexer.REPO_INDEXER_ENABLED = true;
      service = {
        DISABLE_REGISTRATION = true;
        ENABLE_NOTIFY_MAIL = true;
        AUTO_WATCH_NEW_REPOS = false;
      };
      admin.DEFAULT_EMAIL_NOTIFICATIONS = "onmention";
      security = {
        SECRET_KEY = lib.mkForce "";
        SECRET_KEY_URI = "file:${config.sops.secrets."gitea/secret-key".path}";
      };
      cache = {
        ADAPTER = "redis";
        HOST = "redis+socket://${config.services.redis.servers.gitea.unixSocket}?db=0";
        ITEM_TTL = "72h";
      };
      session = {
        COOKIE_SECURE = true;
        PROVIDER = "redis";
        PROVIDER_CONFIG = "redis+socket://${config.services.redis.servers.gitea.unixSocket}?db=1";
      };
      queue = {
        TYPE = "redis";
        CONN_STR = "redis+socket://${config.services.redis.servers.gitea.unixSocket}?db=2";
      };
      database.LOG_SQL = false;
      repository = {
        PREFERRED_LICENSES = lib.concatStringsSep "," [
          "AGPL-3.0-only"
          "AGPL-3.0-or-later"
          "Apache-2.0"
          "BSD-3-Clause"
          "CC-BY-4.0"
          "CC-BY-NC-4.0"
          "CC-BY-NC-ND-4.0"
          "CC-BY-NC-SA-4.0"
          "CC-BY-ND-4.0"
          "CC-BY-SA-4.0"
          "CC0-1.0"
          "GPL-2.0-only"
          "GPL-3.0-only"
          "GPL-3.0-or-later"
          "LGPL-3.0-linking-exception"
          "LGPL-3.0-only"
          "LGPL-3.0-or-later"
          "MIT"
          "MPL-2.0"
          "Unlicense"
        ];
        DEFAULT_REPO_UNITS = lib.concatStringsSep "," [
          "repo.code"
          "repo.issues"
          "repo.pulls"
          "repo.releases"
        ];
      };
      picture = {
        DISABLE_GRAVATAR = true;
        ENABLE_FEDERATED_AVATAR = false;

        AVATAR_MAX_FILE_SIZE = 1024 * 1024 * 5;
        # NOTE: go any bigger than this, and gitea will freeze your gif >:(
        AVATAR_MAX_ORIGIN_SIZE = 1024 * 1024 * 2;
      };
      actions.ENABLED = true;
    };

    dump = {
      enable = true;
      interval = "weekly";
      type = "tar.gz";
    };
  };

  environment.systemPackages = [ cfg.package ];

  systemd.services.gitea = lib.mkIf cfg.enable {
    wants = [ "redis-gitea.service" ];
    after = [ "redis-gitea.service" ];

    serviceConfig = {
      CPUSchedulingPolicy = "batch";
      CacheDirectory = "gitea/repo-archive";
      BindPaths = [
        "%C/gitea/repo-archive:${cfg.stateDir}/data/repo-archive"
      ];
    };
  };

  services.redis.servers.gitea = lib.mkIf cfg.enable {
    enable = true;
    user = config.services.gitea.user;
    save = [ ];
    openFirewall = false;
    port = 5698;
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    locations = {
      "/" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = ''
          client_max_body_size 512M;
        '';
      };
      "/metrics" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = ''
          allow ${values.hosts.ildkule.ipv4}/32;
          allow ${values.hosts.ildkule.ipv6}/128;
          deny all;
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ sshPort ];

  services.rsync-pull-targets = {
    enable = true;
    locations.${cfg.dump.backupDir} = {
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
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGpMVrOppyqYaDiAhqmAuOaRsubFvcQGBGyz+NHB6+0o gitea rsync backup";
    };
  };

  systemd.services.gitea-dump = {
    serviceConfig.ExecStart =
      let
        args = lib.cli.toGNUCommandLineShell { } {
          type = cfg.dump.type;

          # This should be declarative on nixos, no need to backup.
          skip-custom-dir = true;

          # This can be regenerated, no need to backup
          skip-index = true;

          # Logs are stored in the systemd journal
          skip-log = true;
        };
      in
      lib.mkForce "${lib.getExe cfg.package} ${args}";

    # Only keep n backup files at a time
    postStop =
      let
        cu = prog: "'${lib.getExe' pkgs.coreutils prog}'";
        backupCount = 3;
      in
      ''
        for file in $(${cu "ls"} -t1 '${cfg.dump.backupDir}' | ${cu "sort"} --reverse | ${cu "tail"} -n+${toString (backupCount + 1)}); do
          ${cu "rm"} "$file"
        done
      '';
  };
}
