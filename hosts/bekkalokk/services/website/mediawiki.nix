{ values, config, ... }:
{
  sops.secrets = {
    "mediawiki/password" = { };
    "postgres/mediawiki/password" = { };
  };

  services.mediawiki = {
    enable = true;
    name = "PVV";
    passwordFile = config.sops.secrets."mediawiki/password".path;

    virtualHost = {
    };

    database = {
      type = "postgres";
      host = values.bicep.ipv4;
      port = config.services.postgresql.port;
      passwordFile = config.sops.secrets."postgres/mediawiki/password".path;
    };
  };
}
