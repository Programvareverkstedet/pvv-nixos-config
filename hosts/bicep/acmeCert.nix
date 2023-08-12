{ values, ... }:
{
  users.groups.acme.members = [ "nginx" ];

  security.acme.certs."postgres.pvv.ntnu.no" = {
    group = "acme";
    extraDomainNames = [
      # "postgres.pvv.org"
      "bicep.pvv.ntnu.no"
      # "bicep.pvv.org"
      # values.hosts.bicep.ipv4
      # values.hosts.bicep.ipv6
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts."postgres.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;
      # useACMEHost = "postgres.pvv.ntnu.no";
    };
  };
}
