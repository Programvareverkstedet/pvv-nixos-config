{ config, values, ... }:
{
  sops.secrets."postgres/gitea/password" = { };

  services.gitea = {
    enable = true;
    rootUrl = "https://git2.pvv.ntnu.no/";
    stateDir = "/data/gitea";
    appName = "PVV Git";

    enableUnixSocket = true;

    database = {
      type = "postgres";
      host = values.bicep.ipv4;
      port = config.services.postgresql.port;
      passwordFile = config.sops.secrets."postgres/gitea/password".path;
      createDatabase = false;
    };

    settings = {
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
    };
  };
}
