{ config, values, pkgs, lib, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";
  sshPort  = 2222;
in {
  imports = [
    ./ci.nix
  ];

  sops.secrets = {
    "gitea/database" = {
      owner = "gitea";
      group = "gitea";
    };
    # (kerberos password for SMTP and IMAP)
    "gitea/passwd-password" = {
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

    mailerPasswordFile = config.sops.secrets."gitea/passwd-password".path;

    settings = {
      server = {
        DOMAIN   = domain;
        ROOT_URL = "https://${domain}/";
        PROTOCOL = "http+unix";
        SSH_PORT = sshPort;
	      START_SSH_SERVER = true;
      };
      mailer = lib.mkIf config.services.postfix.enable {
        ENABLED = true;
        FROM = "gitea@pvv.ntnu.no";
        PROTOCOL = "smtp";
        SMTP_ADDR = "mail.pvv.ntnu.no";
        SMTP_PORT = 587;
        USER = "gitea@pvv.ntnu.no";
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

  services.gitea-themes.monokai = pkgs.gitea-theme-monokai;

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
    requires = [ "gitea.service" ];
    after = [ "gitea.service" ];
    wantedBy = [ "timers.target" ];
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
