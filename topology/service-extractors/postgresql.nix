{ config, unstablePkgs, lib, ... }:
let
  cfg = config.services.postgresql;
  cfgBak = config.services.postgresqlBackup;
in
{
  config.topology.self.services.postgresql = lib.mkIf cfg.enable {
    name = "PostgreSQL";

    details.listen.text = lib.mkIf cfg.enableTCPIP "0.0.0.0:${toString cfg.settings.port}";
    details.socket.text = "/run/postgresql/.s.PGSQL.${toString cfg.settings.port}";
    details.version.text = cfg.package.version;
    details.dataDir.text = cfg.dataDir;

    # details.backup-time = lib.mkIf cfgBak.enable cfgBak.startAt;
    # details.backup-location = lib.mkIf cfgBak.enable cfgBak.location;
  };
}
