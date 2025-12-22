{ config, pkgs, lib, ... }:
let
  cfg = config.services.gitea;
  GNUPGHOME = "${config.users.users.gitea.home}/gnupg";
in
{
  sops.secrets = {
    "gitea/gpg-signing-key-public" = {
      owner = cfg.user;
      inherit (cfg) group;
      restartUnits = [ "gitea.service" ];
    };
    "gitea/gpg-signing-key-private" = {
      owner = cfg.user;
      inherit (cfg) group;
      restartUnits = [ "gitea.service" ];
    };
  };

  systemd.services.gitea.environment = { inherit GNUPGHOME; };

  systemd.tmpfiles.settings."20-gitea-gnugpg".${GNUPGHOME}.d = {
    inherit (cfg) user group;
    mode = "700";
  };

  systemd.services.gitea-ensure-gnupg-homedir = {
    description = "Import gpg key for gitea";
    environment = { inherit GNUPGHOME; };
    serviceConfig = {
      Type = "oneshot";
      User = cfg.user;
      PrivateNetwork = true;
    };
    script = ''
      ${lib.getExe pkgs.gnupg} --import ${config.sops.secrets."gitea/gpg-signing-key-public".path}
      ${lib.getExe pkgs.gnupg} --import ${config.sops.secrets."gitea/gpg-signing-key-private".path}
    '';
  };

  services.gitea.settings."repository.signing" = {
    SIGNING_KEY = "0549C43374D2253C";
    SIGNING_NAME = "PVV Git";
    SIGNING_EMAIL = "gitea@git.pvv.ntnu.no";
    INITIAL_COMMIT = "always";
    WIKI = "always";
  };
}
