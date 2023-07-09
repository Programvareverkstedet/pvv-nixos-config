{ pkgs, config, ... }:
{
  services.mysql = {
    enable = true;
    dataDir = "/data/mysql";
    package = pkgs.mariadb;
    settings = {
      mysqld = {
        # PVV allows a lot of connections at the same time
        max_connect_errors = 10000;
      };
    };

    # Note: This user also has MAX_USER_CONNECTIONS set to 3, and
    #       a password which can be found in /secrets/ildkule/ildkule.yaml
    ensureUsers = [{
      name = "prometheus_mysqld_exporter";
      ensurePermissions = {
	"*.*" = "PROCESS, REPLICATION CLIENT, SELECT";
      };
    }];
  };

  services.mysqlBackup = {
    enable = true;
    location = "/var/lib/mysql/backups";
  };

  networking.firewall.allowedTCPPorts = [ 3306 ];
}
