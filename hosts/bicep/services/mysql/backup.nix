{
  config,
  lib,
  pkgs,
  values,
  ...
}:
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
        "from=\"principal.pvv.ntnu.no,${values.hosts.principal.ipv6},${values.hosts.principal.ipv4}\""
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
      zstd
    ];

    script =
      let
        rotations = 2;
      in
      ''
        set -euo pipefail

        OUT_FILE="$STATE_DIRECTORY/mysql-dump-$(date --iso-8601).sql.zst"

        mysqldump --all-databases | zstd --compress -9 --rsyncable -o "$OUT_FILE"

        # NOTE: this needs to be a hardlink for rrsync to allow sending it
        rm "$STATE_DIRECTORY/mysql-dump-latest.sql.zst" ||:
        ln -T "$OUT_FILE" "$STATE_DIRECTORY/mysql-dump-latest.sql.zst"

        while [ "$(find "$STATE_DIRECTORY" -type f -printf '.' | wc -c)" -gt ${toString (rotations + 1)} ]; do
          rm "$(find "$STATE_DIRECTORY" -type f -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2)"
        done
      '';

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
