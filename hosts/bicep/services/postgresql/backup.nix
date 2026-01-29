{ config, lib, pkgs, ... }:
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
      zstd
      cfg.package
    ];

    script = let
      rotations = 2;
    in ''
      set -euo pipefail

      OUT_FILE="$STATE_DIRECTORY/postgresql-dump-$(date --iso-8601).sql.zst"

      pg_dumpall -U postgres | zstd --compress -9 --rsyncable -o "$OUT_FILE"

      rm "$STATE_DIRECTORY/postgresql-dump-latest.sql.zst" ||:
      ln -s -T "$OUT_FILE" "$STATE_DIRECTORY/postgresql-dump-latest.sql.zst"

      while [ $(find -type f "$STATE_DIRECTORY" -printf '.' | wc -c) -gt ${toString rotations} ]; do
        rm $(find "$STATE_DIRECTORY" -type f -printf '%T+ %p\n' | sort | head -n 1 | cut -d' ' -f2)
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
