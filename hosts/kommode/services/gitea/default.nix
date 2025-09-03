{ config, values, lib, pkgs, unstablePkgs, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort  = 2222;
in {
  imports = [
    ./customization
    ./gpg.nix
    ./import-users
    ./web-secret-provider
  ];

  sops.secrets = let
    defaultConfig = {
      owner = "gitea";
      group = "gitea";
    };
  in {
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
        DOMAIN   = domain;
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
      session.COOKIE_SECURE = true;
      security = {
        SECRET_KEY = lib.mkForce "";
        SECRET_KEY_URI = "file:${config.sops.secrets."gitea/secret-key".path}";
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
      };
      actions.ENABLED = true;
      ui = {
        REACTIONS = lib.concatStringsSep "," [
          "+1"
          "-1"
          "laugh"
          "confused"
          "heart"
          "hooray"
          "rocket"
          "eyes"
          "100"
          "anger"
          "astonished"
          "no_good"
          "ok_hand"
          "pensive"
          "pizza"
          "point_up"
          "sob"
          "skull"
          "upside_down_face"
          "shrug"
        ];
      };
      "ui.meta".DESCRIPTION = "Bokstavelig talt programvareverkstedet";
    };

    dump = {
      enable = true;
      interval = "weekly";
      type = "tar.gz";
    };
  };

  environment.systemPackages = [ cfg.package ];

  systemd.services.gitea.serviceConfig.CPUSchedulingPolicy = "batch";

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

  # Only keep n backup files at a time
  systemd.services.gitea-dump.postStop = let
    cu = prog: "'${lib.getExe' pkgs.coreutils prog}'";
    backupCount = 3;
  in ''
    for file in $(${cu "ls"} -t1 '${cfg.dump.backupDir}' | ${cu "sort"} --reverse | ${cu "tail"} -n+${toString (backupCount - 1)}); do
      ${cu "rm"} "$file"
    done
  '';
}
