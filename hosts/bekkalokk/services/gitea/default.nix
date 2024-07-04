{ config, values, pkgs, lib, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort  = 2222;
in {
  imports = [
    ./ci.nix
    ./import-users.nix
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
    stateDir = "/data/gitea";
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
      };
      mailer = {
        ENABLED = true;
        FROM = "gitea@pvv.ntnu.no";
        PROTOCOL = "smtp";
        SMTP_ADDR = "smtp.pvv.ntnu.no";
        SMTP_PORT = 587;
        USER = "gitea@pvv.ntnu.no";
      };
      indexer.REPO_INDEXER_ENABLED = true;
      service.DISABLE_REGISTRATION = true;
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
      "ui.meta".DESCRIPTION = "Bokstavelig talt programvareverkstedet";
    };
  };

  environment.systemPackages = [ cfg.package ];

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
      extraConfig = ''
        client_max_body_size 512M;
      '';
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
      logo-svg = ../../../../assets/logo_blue_regular.svg;
      logo-png = ../../../../assets/logo_blue_regular.png;
    in ''
      install -Dm444 ${logo-svg} ${cfg.customDir}/public/assets/img/logo.svg
      install -Dm444 ${logo-png} ${cfg.customDir}/public/assets/img/logo.png
      install -Dm444 ${./loading.apng} ${cfg.customDir}/public/assets/img/loading.png
    '';
  };
}
