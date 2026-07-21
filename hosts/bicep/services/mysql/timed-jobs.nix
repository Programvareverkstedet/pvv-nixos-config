{ config, lib, pkgs, ... }:
let
  cfg = config.services.mysql;
in
{
  config = lib.mkIf cfg.enable {
    systemd.services = {
      mysql-analyze = {
        requires = [ "mysql.service" ];
        after = [ "mysql.service" ];
        description = "Refresh MariaDB optimizer statistics for all databases";
        startAt = "Mon 05:00:00";
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;

          Nice = 19;
          IOSchedulingClass = "best-effort";
          IOSchedulingPriority = 7;

          ExecStart = "${lib.getExe' cfg.package "mariadb-check"} --all-databases --analyze";
        };
      };

      mysql-optimize = {
        requires = [ "mysql.service" ];
        after = [ "mysql.service" ];
        description = "Check, repair and optimize all MariaDB databases";
        startAt = "*-*-01 04:00:00";
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;

          Nice = 19;
          IOSchedulingClass = "best-effort";
          IOSchedulingPriority = 7;

          ExecStart = [
            "${lib.getExe' cfg.package "mariadb-check"} --all-databases --auto-repair"
            "${lib.getExe' cfg.package "mariadb-check"} --all-databases --optimize"
          ];
        };
      };
    };
  };
}
