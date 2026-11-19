{ lib, ... }:
let
  pools = map (pool: "phpfpm-${pool}") [
    "idp"
    "mediawiki"
    "pvv-nettsiden"
    "roundcube"
    "snappymail"
  ];
in
{
  options.services.phpfpm.pools = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      config.settings = {
        "php_admin_flag[log_errors]" = lib.mkDefault true;
        "php_admin_value[error_log]" = lib.mkDefault "syslog";
        "php_admin_value[syslog.ident]" = lib.mkDefault "php-${name}";
        "catch_workers_output" = lib.mkDefault true;
        "decorate_workers_output" = lib.mkDefault false;
      };
    }));
  };

  config.services.phpfpm.settings."log_limit" = lib.mkDefault 8192;

  # Source: https://www.pierreblazquez.com/2023/06/17/how-to-harden-apache-php-fpm-daemons-using-systemd/
  config.systemd.services = lib.genAttrs pools (_: {
    serviceConfig = let
      caps = [
        "CAP_NET_BIND_SERVICE"
        "CAP_SETGID"
        "CAP_SETUID"
        "CAP_CHOWN"
        "CAP_KILL"
        "CAP_IPC_LOCK"
        "CAP_DAC_OVERRIDE"
      ];
    in {
      AmbientCapabilities = caps;
      CapabilityBoundingSet = caps;
      DeviceAllow = [ "" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = false;
      NoNewPrivileges = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RemoveIPC = true;
      UMask = "0077";
      RestrictNamespaces = "~mnt";
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      KeyringMode = "private";
      SystemCallFilter = [
        "@system-service"
      ];
    };
  });
}
