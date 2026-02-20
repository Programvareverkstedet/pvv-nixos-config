{
  config,
  pkgs,
  lib,
  values,
  ...
}:
let
  cfg = config.services.mysql;
  dataDir = "/data/mysql";
in
{
  imports = [ ./backup.nix ];

  sops.secrets."mysql/password" = {
    owner = "mysql";
    group = "mysql";
  };

  users.mysql.passwordFile = config.sops.secrets."mysql/password".path;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb_118;
    settings = {
      mysqld = {
        # PVV allows a lot of connections at the same time
        max_connect_errors = 10000;
        bind-address = values.services.mysql.ipv4;
        skip-networking = 0;

        # This was needed in order to be able to use all of the old users
        # during migration from knakelibrak to bicep in Sep. 2023
        secure_auth = 0;

        slow-query-log = 1;
        slow-query-log-file = "/var/log/mysql/mysql-slow.log";
      };
    };

    # Note: This user also has MAX_USER_CONNECTIONS set to 3, and
    #       a password which can be found in /secrets/ildkule/ildkule.yaml
    #       We have also changed both the host and auth plugin of this user
    #       to be 'ildkule.pvv.ntnu.no' and 'mysql_native_password' respectively.
    ensureUsers = [
      {
        name = "prometheus_mysqld_exporter";
        ensurePermissions = {
          "*.*" = "PROCESS, REPLICATION CLIENT, SELECT, SLAVE MONITOR";
        };
      }
    ];
  };

  networking.firewall.allowedTCPPorts = lib.mkIf cfg.enable [ 3306 ];

  systemd.tmpfiles.settings."10-mysql".${dataDir}.d = lib.mkIf cfg.enable {
    inherit (cfg) user group;
    mode = "0700";
  };

  systemd.services.mysql = lib.mkIf cfg.enable {
    after = [
      "systemd-tmpfiles-setup.service"
      "systemd-tmpfiles-resetup.service"
    ];

    serviceConfig = {
      BindPaths = [ "${dataDir}:${cfg.dataDir}" ];

      LogsDirectory = "mysql";

      IPAddressDeny = "any";
      IPAddressAllow = [
        values.ipv4-space
        values.ipv6-space
        values.hosts.ildkule.ipv4
        values.hosts.ildkule.ipv6
      ];
    };
  };
}
