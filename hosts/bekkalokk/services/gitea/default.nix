{ config, values, lib, unstablePkgs, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort  = 2222;
in {
  imports = [
    ./customization.nix
    ./gpg.nix
    ./import-users
    ./web-secret-provider
  ];

  sops.secrets = {
    "gitea/database" = {
      owner = "gitea";
      group = "gitea";
    };
    "gitea/email-password" = {
      owner = "gitea";
      group = "gitea";
    };
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
        START_SSH_SERVER = true;
        START_LFS_SERVER = true;
        LANDING_PAGE = "explore";
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
      type = "tar.gz";
    };
  };

  environment.systemPackages = [ cfg.package ];

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
          deny all;
        '';
      };
    };
  };

  environment.robots-txt."gitea" = {
    virtualHost = domain;
    rules = [
      {
        pre_comment = ''
          Gitea internals

          See these for more information:
          - https://gitea.com/robots.txt
          - https://codeberg.org/robots.txt
        '';
        User-agent = "*";
        Disallow = [
          "/api/*"
          "/avatars"
          "/*/*/src/commit/*"
          "/*/*/commit/*"
          "/*/*/*/refs/*"
          "/*/*/*/star"
          "/*/*/*/watch"
          "/*/*/labels"
          "/*/*/activity/*"
          "/vendor/*"
          "/swagger.*.json"
          "/repo/create"
          "/repo/migrate"
          "/org/create"
          "/*/*/fork"
          "/*/*/watchers"
          "/*/*/stargazers"
          "/*/*/forks"
          "*/.git/"
          "/*.git"
          "/*.atom"
          "/*.rss"
        ];
      }
      {
        pre_comment = "Language Spam";
        Disallow = "/*?lang=";
      }
      {
        pre_comment = ''
          AI bots

          Sourced from:
          - https://www.vg.no/robots.txt
          - https://codeberg.org/robots.txt
        '';
        User-agent = [
          "AI2Bot"
          "Ai2Bot-Dolma"
          "Amazonbot"
          "Applebot-Extended"
          "Bytespider"
          "CCBot"
          "ChatGPT-User"
          "Claude-Web"
          "ClaudeBot"
          "Crawlspace"
          "Diffbot"
          "FacebookBot"
          "FriendlyCrawler"
          "GPTBot"
          "Google-Extended"
          "ICC-Crawler"
          "ImagesiftBot"
          "Kangaroo Bot"
          "Meta-ExternalAgent"
          "OAI-SearchBot"
          "Omgili"
          "Omgilibot"
          "PanguBot"
          "PerplexityBot"
          "PetalBot"
          "Scrapy"
          "SemrushBot-OCOB"
          "Sidetrade indexer bot"
          "Timpibot"
          "VelenPublicWebCrawler"
          "Webzio-Extended"
          "YouBot"
          "anthropic-ai"
          "cohere-ai"
          "cohere-training-data-crawler"
          "facebookexternalhit"
          "iaskspider/2.0"
          "img2dataset"
          "meta-externalagent"
          "omgili"
          "omgilibot"
        ];
        Disallow = "/";
      }
      {
        Crawl-delay = "2";
      }
      {
        Sitemap = "https://${domain}/sitemap.xml";
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ sshPort ];
}
