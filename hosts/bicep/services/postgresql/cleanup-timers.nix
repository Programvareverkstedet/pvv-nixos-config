{ config, lib, pkgs, ... }:
let
  cfg = config.services.postgresql;
in
{
  config = lib.mkIf cfg.enable {
    systemd.services = {
      postgresql-repack = {
        requires = [ "postgresql.service" ];
        after = [ "postgresql.target" ];
        description = "Repack all PostgreSQL databases";
        startAt = "Mon 06:00:00";
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          Group = "postgres";

          ExecStart = "${lib.getExe cfg.package.pkgs.pg_repack} --port=${builtins.toString cfg.settings.port} --all";
        };
      };

      postgresql-vacuum-analyze = {
        requires = [ "postgresql.service" ];
        after = [ "postgresql.target" ];
        description = "Vacuum and analyze all PostgreSQL databases";
        startAt = "Tue 06:00:00";
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          Group = "postgres";

          ExecStart = "${lib.getExe' cfg.package "psql"} --port=${builtins.toString cfg.settings.port} -tAc 'VACUUM ANALYZE'";
        };
      };
    };
  };
}
