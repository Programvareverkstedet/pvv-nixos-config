{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.services.synapse-auto-compressor;
in
{
  services.synapse-auto-compressor = {
    # enable = true;
    postgresUrl = "postgresql://matrix-synapse@/synapse?host=/run/postgresql";
  };

  # NOTE: nixpkgs has some broken asserts, vendored the entire unit
  systemd.services.synapse-auto-compressor = {
    description = "synapse-auto-compressor";
    requires = [
      "postgresql.target"
    ];
    inherit (cfg) startAt;
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      User = "matrix-synapse";
      PrivateTmp = true;
      ExecStart = utils.escapeSystemdExecArgs [
        "${cfg.package}/bin/synapse_auto_compressor"
        "-p"
        cfg.postgresUrl
        "-c"
        cfg.settings.chunk_size
        "-n"
        cfg.settings.chunks_to_compress
        "-l"
        (lib.concatStringsSep "," (map toString cfg.settings.levels))
      ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateUsers = true;
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      ProcSubset = "pid";
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
    };
  };
}
