{ config, lib, pkgs, values, ... }:
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
      diffutils
      zstd
    ];

    script = ''
      set -euo pipefail

      dump() {
        local name="$1" out tmp
        out="$STATE_DIRECTORY/$name.sql.zst"
        tmp="$out.tmp"
        shift
        "$@" | zstd -9 --rsyncable -f -o "$tmp"
        if cmp -s "$tmp" "$out" 2>/dev/null; then
          rm -f "$tmp"
        else
          mv -f "$tmp" "$out"
        fi
      }

      declare -A keep
      while IFS= read -r db; do
        [ -n "$db" ] || continue
        dump "$db" mysqldump --skip-dump-date --databases "$db"
        keep["$db.sql.zst"]=1
      done < <(mysql -N -e 'SHOW DATABASES' | grep -vE '^(information_schema|performance_schema)$')

      # drop dumps of databases that no longer exist
      for f in "$STATE_DIRECTORY"/*.sql.zst; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        [ -n "''${keep[$base]:-}" ] || rm -f "$f"
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
