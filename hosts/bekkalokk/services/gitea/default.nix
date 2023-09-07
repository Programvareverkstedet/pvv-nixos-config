{ config, values, pkgs, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort  = 2222;
in {
  sops.secrets = {
    "gitea/database" = {
      owner = "gitea";
      group = "gitea";
    };
    "gitea/passwd-ssh-key" = { };
    "gitea/ssh-known-hosts" = { };
    "gitea/import-user-env" = { };
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
      indexer = {
      	REPO_INDEXER_ENABLED = true;
      };
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      database.LOG_SQL = false;
      picture = {
        DISABLE_GRAVATAR = true;
        ENABLE_FEDERATED_AVATAR = false;
      };
      "ui.meta".DESCRIPTION = "Bokstavelig talt programvareverkstedet";
    };
  };

  environment.systemPackages = [ cfg.package ];

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 512M;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ sshPort ];

  # Automatically import users
  systemd.services.gitea-import-users = {
    enable = true;
    preStart=''${pkgs.rsync}/bin/rsync -e "${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=$CREDENTIALS_DIRECTORY/ssh-known-hosts -i $CREDENTIALS_DIRECTORY/sshkey" -a pvv@smtp.pvv.ntnu.no:/etc/passwd /tmp/passwd-import'';
    serviceConfig = {
      ExecStart = pkgs.writers.writePython3 "gitea-import-users" { libraries = [ pkgs.python3Packages.requests ]; } (builtins.readFile ./gitea-import-users.py);
      LoadCredential=[
        "sshkey:${config.sops.secrets."gitea/passwd-ssh-key".path}"
        "ssh-known-hosts:${config.sops.secrets."gitea/ssh-known-hosts".path}"
      ];
      DynamicUser="yes";
      EnvironmentFile=config.sops.secrets."gitea/import-user-env".path;
    };
  };

  systemd.timers.gitea-import-users = {
    enable = true;
    requires = [ "gitea.service" ];
    after = [ "gitea.service" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
      Unit = "gitea-import-users.service";
    };
  };

  system.activationScripts.linkGiteaLogo.text = let
    logo-svg = ../../../../assets/logo_blue_regular.svg;
    logo-png = ../../../../assets/logo_blue_regular.png;
  in ''
    install -Dm444 ${logo-svg} ${cfg.stateDir}/custom/public/img/logo.svg
    install -Dm444 ${logo-png} ${cfg.stateDir}/custom/public/img/logo.png
    install -Dm444 ${./loading.apng} ${cfg.stateDir}/custom/public/img/loading.png
  '';
}
