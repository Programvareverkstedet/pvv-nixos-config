{ config, lib, pkgs, values, ... }:
let
  mcfg = config.services.pvv-userweb;
in
{
  systemd.targets.sockets.wants = [
    "httpd-log-processor@access.socket"
    "httpd-log-processor@error.socket"
  ];

  systemd.sockets."httpd-log-processor@" = lib.mkIf config.services.httpd.enable {
    requiredBy = [ "userweb.target" ];
    socketConfig = {
      ListenFIFO = "/run/httpd-log-processor-%i.fifo";
      RemoveOnStop = true;

      SocketUser = "wwwrun";
      SocketGroup = "wwwrun";
      SocketMode = "0600";
    };
  };

  systemd.services."httpd-log-processor@" = lib.mkIf config.services.httpd.enable {
    requiredBy = [ "userweb.target" ];
    after = [ "httpd-passwd-sync.service" ];
    requires = [ "httpd-passwd-sync.service" ];

    serviceConfig = {
      User = "wwwrun";
      Group = "wwwrun";
      Slice = "system-userweb.slice";
      Restart = "on-failure";

      StandardInput = "socket";
      StandardOutput = "journal";
      StandardError = "journal";

      ExecStart = "${lib.getExe mcfg.apacheLogProcessorPackage} %i";

      AmbientCapabilities = [ "CAP_SETUID" "CAP_SETGID" ];
      CapabilityBoundingSet = [ "CAP_SETUID" "CAP_SETGID" ];
      DeviceAllow = [ "" ];
      IPAddressDeny = "any";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      PrivateIPC = true;
      PrivateTmp = true;
      # PrivateUsers = true;
      ProcSubset = "pid";
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = "tmpfs";
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      RemoveIPC = true;
      RestrictAddressFamilies = [ "" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SocketBindDeny = "any";
      SystemCallArchitectures = "native";
      SystemCallFilter = [
         "@system-service"
         "@setuid"
      ];
      UMask = "0077";

      RootDirectory = "/run/httpd-log-processor-%i/root-mnt";
      MountAPIVFS = true;

      RuntimeDirectoryMode = "0750";
      RuntimeDirectory = [ "httpd-log-processor-%i/root-mnt" ];
      BindReadOnlyPaths = [
        builtins.storeDir
        "/etc"

        "/var/lib/httpd-passwd-sync/passwd:/etc/passwd"
        "/var/lib/httpd-passwd-sync/group:/etc/group"

        "${pkgs.writeText "userweb-fake-nsswitch.conf" ''
          passwd:    files
          group:     files
          shadow:    files
          sudoers:   files

          hosts:     mymachines resolve [!UNAVAIL=return] files myhostname dns
          networks:  files

          ethers:    files
          services:  files
          protocols: files
          rpc:       files

          subuid:    files
          subgid:    files
        ''}:/etc/nsswitch.conf"
      ] ++ lib.optionals mcfg.debugMode [
        "/bin"
      ];
      BindPaths = map (l: "/run/pvv-home-mounts/${l}:/home/pvv/${l}") mcfg.homeLetters ++ [
        "/var/log/httpd"
      ];
    };
  };
}
