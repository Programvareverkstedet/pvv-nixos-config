{ pkgs, lib, config, values, ... }:
let
  backupDir = "/var/lib/mysql/backups";
in
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

  networking.firewall.allowedTCPPorts = [ 3306 ];

  systemd.services.mysql.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      values.ipv4-space
      values.ipv6-space
    ];
  };

  # NOTE: instead of having the upstream nixpkgs postgres backup unit trigger
  #       another unit, it was easier to just make one ourselves
  systemd.services."backup-mysql" = {
    description = "Backup MySQL data";
    requires = [ "mysql.service" ];

    path = [
      pkgs.coreutils
      pkgs.rsync
      pkgs.gzip
      config.services.mysql.package
    ];

    script = let
      rotations = 10;
      # rsyncTarget = "root@isvegg.pvv.ntnu.no:/mnt/backup1/bicep/mysql";
      rsyncTarget = "/data/backup/mysql";
    in ''
      set -eo pipefail

      mysqldump --all-databases | gzip -c -9 --rsyncable > "${backupDir}/$(date --iso-8601)-dump.sql.gz"

      while [ $(ls -1 "${backupDir}" | wc -l) -gt ${toString rotations} ]; do
        rm $(find "${backupDir}" -type f -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2)
      done

      rsync -avz --delete "${backupDir}" '${rsyncTarget}'
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "mysql";
      Group = "mysql";
      UMask = "0077";

      Nice = 19;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;

      ReadWritePaths = [
        backupDir
        "/data/backup/mysql" # NOTE: should not be part of this option once rsyncTarget is remote
      ];
    };

    startAt = "*-*-* 02:15:00";
  };

  systemd.tmpfiles.settings."10-mysql-backup".${backupDir}.d = {
    user = "mysql";
    group = "mysql";
    mode = "700";
  };
}
