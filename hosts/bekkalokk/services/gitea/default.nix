{ config, values, fp, pkgs, lib, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort  = 2222;
in {
  imports = [
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

  networking.firewall.allowedTCPPorts = [ sshPort ];

  # Extra customization

  services.gitea-themes.monokai = pkgs.gitea-theme-monokai;

  systemd.services.install-gitea-customization = {
    description = "Install extra customization in gitea's CUSTOM_DIR";
    wantedBy = [ "gitea.service" ];
    requiredBy = [ "gitea.service" ];

    serviceConfig =  {
      Type = "oneshot";
      User = cfg.user;
      Group = cfg.group;
    };

    script = let
      logo-svg = fp /assets/logo_blue_regular.svg;
      logo-png = fp /assets/logo_blue_regular.png;
      extraLinks = pkgs.writeText "gitea-extra-links.tmpl" ''
        <a class="item" href="https://www.pvv.ntnu.no/">PVV</a>
        <a class="item" href="https://wiki.pvv.ntnu.no/">Wiki</a>
        <a class="item" href="https://git.pvv.ntnu.no/Drift/-/projects/4">Tokyo Drift Issues</a>
      '';

      project-labels = (pkgs.formats.yaml { }).generate "gitea-project-labels.yaml" {
        labels = lib.importJSON ./labels/projects.json;
      };
    in ''
      install -Dm444 ${logo-svg} ${cfg.customDir}/public/assets/img/logo.svg
      install -Dm444 ${logo-png} ${cfg.customDir}/public/assets/img/logo.png
      install -Dm444 ${./loading.apng} ${cfg.customDir}/public/assets/img/loading.png
      install -Dm444 ${extraLinks} ${cfg.customDir}/templates/custom/extra_links.tmpl
      install -Dm444 ${project-labels} ${cfg.customDir}/options/label/project-labels.yaml
    '';
  };
}
