{ config, lib, pkgs, values, ... }:
let
  cfg = config.services.postgresql;
  backupDir = "/data/postgresql-backups";
in
{
  # services.postgresqlBackup = lib.mkIf cfg.enable {
  #   enable = true;
  #   location = "/var/lib/postgresql-backups";
  #   backupAll = true;
  # };

  systemd.tmpfiles.settings."10-postgresql-backups".${backupDir}.d = {
	  user = "postgres";
	  group = "postgres";
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
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvO7QX7QmwSiGLXEsaxPIOpAqnJP3M+qqQRe5dzf8gJ postgresql rsync backup";
    };
  };

  # NOTE: instead of having the upstream nixpkgs postgres backup unit trigger
  #       another unit, it was easier to just make one ourselves
  systemd.services."backup-postgresql" = {
    description = "Backup PostgreSQL data";
    requires = [ "postgresql.service" ];

    path = with pkgs; [
      coreutils
      diffutils
      zstd
      cfg.package
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
      dump globals pg_dumpall -U postgres --globals-only --restrict-key=backup
      keep[globals.sql.zst]=1

      while IFS= read -r db; do
        [ -n "$db" ] || continue
        dump "$db" pg_dump -U postgres -C -d "$db" --restrict-key=backup
        keep["$db.sql.zst"]=1
      done < <(psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datallowconn ORDER BY datname")

      # drop dumps of databases that no longer exist
      for f in "$STATE_DIRECTORY"/*.sql.zst; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        [ -n "''${keep[$base]:-}" ] || rm -f "$f"
      done
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      UMask = "0077";

      Nice = 19;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;

      StateDirectory = [ "postgresql-backups" ];
      BindPaths = [ "${backupDir}:/var/lib/postgresql-backups" ];

      # TODO: hardening
    };

    startAt = "*-*-* 01:15:00";
  };
}
