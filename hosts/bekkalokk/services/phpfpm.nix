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
  # Source: https://www.pierreblazquez.com/2023/06/17/how-to-harden-apache-php-fpm-daemons-using-systemd/
  systemd.services = lib.genAttrs pools (_: {
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
