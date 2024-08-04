{ pkgs, lib, config, values, ... }:
{
  sops.secrets."mysql/password" = {
    owner = "mysql";
    group = "mysql";
  };

  users.mysql.passwordFile = config.sops.secrets."mysql/password".path;

  services.mysql = {
    enable = true;
    dataDir = "/data/mysql";
    package = pkgs.mariadb;
    settings = {
      mysqld = {
        # PVV allows a lot of connections at the same time
        max_connect_errors = 10000;
        bind-address = values.services.mysql.ipv4;
        skip-networking = 0;

        # This was needed in order to be able to use all of the old users
        # during migration from knakelibrak to bicep in Sep. 2023
        secure_auth = 0;
      };
    };

    # Note: This user also has MAX_USER_CONNECTIONS set to 3, and
    #       a password which can be found in /secrets/ildkule/ildkule.yaml
    #       We have also changed both the host and auth plugin of this user
    #       to be 'ildkule.pvv.ntnu.no' and 'mysql_native_password' respectively.
    ensureUsers = [{
      name = "prometheus_mysqld_exporter";
      ensurePermissions = {
        "*.*" = "PROCESS, REPLICATION CLIENT, SELECT, SLAVE MONITOR";
      };
    }];
  };

  services.mysqlBackup = {
    enable = true;
    location = "/var/lib/mysql/backups";
  };

  networking.firewall.allowedTCPPorts = [ 3306 ];

  systemd.services.mysql.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      values.ipv4-space
      values.ipv6-space
    ];
  };
}
