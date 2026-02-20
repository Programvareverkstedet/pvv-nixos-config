{
  config,
  unstablePkgs,
  lib,
  ...
}:
let
  cfg = config.services.mysql;
  cfgBak = config.services.mysqlBackup;
in
{
  config.topology.self.services.mysql = lib.mkIf cfg.enable {
    name = "MySQL";
    icon = "${unstablePkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/mysql.svg";

    details.listen.text = "${cfg.settings.mysqld.bind-address or "127.0.0.1"}:${
      toString (cfg.settings.mysqld.port or 3306)
    }";
    details.socket.text = cfg.settings.mysqld.socket or "/run/mysqld/mysqld.sock";
    details.type.text = cfg.package.pname;
    details.dataDir.text = cfg.dataDir;

    # details.backup-time = lib.mkIf cfgBak.enable cfgBak.calendar;
    # details.backup-location = lib.mkIf cfgBak.enable cfgBak.location;
  };
}
