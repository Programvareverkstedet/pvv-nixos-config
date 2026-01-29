{ config, lib, pkgs, ... }:
let
  cfg = config.services.mysql;
  backupDir = "/data/mysql-backups";
in
{
  # services.mysqlBackup = lib.mkIf cfg.enable {
  #   enable = true;
  #   location = "/var/lib/mysql-backups";
  # };

  systemd.tmpfiles.settings."10-mysql-backups".${backupDir}.d = {
	  user = "mysql";
	  group = "mysql";
	  mode = "700";
	};

  services.rsync-pull-targets = lib.mkIf cfg.enable {
    enable = true;
    locations.${backupDir} = {
      user = "root";
      rrsyncArgs.ro = true;
      authorizedKeysAttrs = [
        "restrict"
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgj55/7Cnj4cYMJ5sIkl+OwcGeBe039kXJTOf2wvo9j mysql rsync backup";
    };
  };

  # NOTE: instead of having the upstream nixpkgs postgres backup unit trigger
  #       another unit, it was easier to just make one ourselves.
  systemd.services."backup-mysql" = lib.mkIf cfg.enable {
    description = "Backup MySQL data";
    requires = [ "mysql.service" ];

    path = with pkgs; [
      cfg.package
      coreutils
      gzip
    ];

    script = let
      rotations = 1;
    in ''
      set -eo pipefail

      mysqldump --all-databases | gzip -c -9 --rsyncable > "/var/lib/mysql-backups/mysql-dump.sql.gz"
    '';

    # NOTE: keep multiple backups and symlink latest one once we have more disk again
    # mysqldump --all-databases | gzip -c -9 --rsyncable > "${backupDir}/$(date --iso-8601)-dump.sql.gz"

    # while [ $(ls -1 "${backupDir}" | wc -l) -gt ${toString rotations} ]; do
    #   rm $(find "${backupDir}" -type f -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2)
    # done

    serviceConfig = {
      Type = "oneshot";
      User = "mysql";
      Group = "mysql";
      UMask = "0077";

      Nice = 19;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;

      StateDirectory = [ "mysql-backups" ];
      BindPaths = [ "${backupDir}:/var/lib/mysql-backups" ];

      # TODO: hardening
    };

    startAt = "*-*-* 02:15:00";
  };
}
