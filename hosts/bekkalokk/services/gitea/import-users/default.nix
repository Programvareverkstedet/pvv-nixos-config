{ config, pkgs, lib, ... }:
let
  cfg = config.services.gitea;
in
{
  sops.secrets = {
    "gitea/passwd-ssh-key" = { };
    "gitea/ssh-known-hosts" = { };
    "gitea/import-user-env" = { };
  };

  systemd.services.gitea-import-users = lib.mkIf cfg.enable {
    enable = true;
    preStart=''${pkgs.rsync}/bin/rsync -e "${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=$CREDENTIALS_DIRECTORY/ssh-known-hosts -i $CREDENTIALS_DIRECTORY/sshkey" -a pvv@smtp.pvv.ntnu.no:/etc/passwd /tmp/passwd-import'';
    serviceConfig = {
      ExecStart = pkgs.writers.writePython3 "gitea-import-users" {
        libraries = with pkgs.python3Packages; [ requests ];
      } (builtins.readFile ./gitea-import-users.py);
      LoadCredential=[
        "sshkey:${config.sops.secrets."gitea/passwd-ssh-key".path}"
        "ssh-known-hosts:${config.sops.secrets."gitea/ssh-known-hosts".path}"
      ];
      DynamicUser="yes";
      EnvironmentFile=config.sops.secrets."gitea/import-user-env".path;
    };
  };

  systemd.timers.gitea-import-users = lib.mkIf cfg.enable {
    requires = [ "gitea.service" ];
    after = [ "gitea.service" ];
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
      Unit = "gitea-import-users.service";
    };
  };
}
