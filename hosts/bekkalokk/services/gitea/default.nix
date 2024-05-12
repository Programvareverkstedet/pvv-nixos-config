{ config, values, pkgs, ... }:
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
  };

  services.gitea = {
    enable = true;
    stateDir = "/data/gitea";
    appName = "PVV Git";

    database = {
      type = "postgres";
      host = "postgres.pvv.ntnu.no";
      port = config.services.postgresql.port;
      passwordFile = config.sops.secrets."gitea/database".path;
      createDatabase = false;
    };

    settings = {
      server = {
        DOMAIN   = domain;
        ROOT_URL = "https://${domain}/";
        PROTOCOL = "http+unix";
        SSH_PORT = sshPort;
        START_SSH_SERVER = true;
      };
      indexer.REPO_INDEXER_ENABLED = true;
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      database.LOG_SQL = false;
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
      install -Dm444 ${logo-svg} ${cfg.customDir}/public/img/logo.svg
      install -Dm444 ${logo-png} ${cfg.customDir}/public/img/logo.png
      install -Dm444 ${./loading.apng} ${cfg.customDir}/public/img/loading.png
    '';
  };
}
