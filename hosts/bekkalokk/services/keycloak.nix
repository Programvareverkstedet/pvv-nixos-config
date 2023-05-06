{ pkgs, config, values, ... }:
{
  sops.secrets."keys/postgres/keycloak" = {
    owner = "keycloak";
    group = "keycloak";
    restartUnits = [ "keycloak.service" ];
  };

  services.keycloak = {
    enable = true;

    settings = {
      hostname = "auth.pvv.ntnu.no";
      # hostname-strict-backchannel = true;
    };

    database = {
      host = values.hosts.bicep.ipv4;
      createLocally = false;
      passwordFile = config.sops.secrets."keys/postgres/keycloak".path;
      caCert = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
  };
}
