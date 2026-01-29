{ config, lib, ... }:
let
  cfg = config.services.postgresql;
in
{
  services.postgresqlBackup = lib.mkIf cfg.enable {
    enable = true;
    location = "/var/lib/postgres-backups";
    backupAll = true;
  };

  services.rsync-pull-targets = lib.mkIf cfg.enable {
    enable = true;
    locations.${config.services.postgresqlBackup.location} = {
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
}
