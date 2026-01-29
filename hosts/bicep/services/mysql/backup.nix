{ config, lib, ... }:
let
  cfg = config.services.mysql;
in
{
  services.mysqlBackup = lib.mkIf cfg.enable {
    enable = true;
    location = "/var/lib/mysql-backups";
  };

  services.rsync-pull-targets = lib.mkIf cfg.enable {
    enable = true;
    locations.${config.services.mysqlBackup.location} = {
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
}
