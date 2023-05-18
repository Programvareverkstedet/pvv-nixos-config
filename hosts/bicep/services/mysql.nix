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
  };

  services.mysqlBackup = {
    enable = true;
    location = "/var/lib/mysql/backups";
  };
}
