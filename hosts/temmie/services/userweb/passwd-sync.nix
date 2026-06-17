{ config, lib, pkgs, values, ... }:
let
  mcfg = config.services.pvv-userweb;
in
{
  config = lib.mkIf mcfg.enable {
    sops.secrets = {
      "httpd/passwd-ssh-key" = { };
      "httpd/ssh-known-hosts" = { };
    };

    # NOTE: because we are running as `DynamicUser` and we want the result files to be available to
    #       other services, this directory needs to be created via systemd-tmpfiles
    systemd.tmpfiles.settings."10-httpd-passwd-sync"."/var/lib/httpd-passwd-sync".d = {
      user = "root";
      group = "root";
      mode = "0700";
    };

    systemd.timers.httpd-passwd-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "httpd-passwd-sync.service";
      };
    };

    systemd.services."httpd-passwd-sync" = {
      requiredBy = [ "userweb.target" ];
      after = [
        "systemd-tmpfiles-setup.service"
        "systemd-tmpfiles-resetup.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        Slice = "system-userweb.slice";
        Restart = "on-failure";
        RestartSec = "3s";

        DynamicUser = true;

        LoadCredential = [
          "sshkey:${config.sops.secrets."httpd/passwd-ssh-key".path}"
          "ssh-known-hosts:${config.sops.secrets."httpd/ssh-known-hosts".path}"
        ];
        ExecStart = let
          rsyncArgs = lib.cli.toCommandLineShellGNU { } {
            verbose = true;
            compress = true;
            rsh = "${lib.getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o UserKnownHostsFile=%d/ssh-known-hosts -i %d/sshkey";
          };
          inputDir = "/run/httpd-passwd-sync/in";
          wipDir = "/run/httpd-passwd-sync/wip";
          outputDir = "/var/lib/httpd-passwd-sync";
        in [
          "${lib.getExe pkgs.rsync} ${rsyncArgs} pvv@smtp.pvv.ntnu.no:/etc/passwd ${inputDir}/"
          "${lib.getExe pkgs.rsync} ${rsyncArgs} pvv@smtp.pvv.ntnu.no:/etc/group ${inputDir}/"

          (let
            args = lib.cli.toCommandLineShellGNU { } {
              passwd-file = "${inputDir}/passwd";
              group-file = "${inputDir}/group";
              output-dir = wipDir;
              shadow-file = pkgs.emptyFile;

              output-passwd = true;

              ignore-user-file = toString ./ignore_user_file.txt;
              ignore-group-file = toString ./ignore_group_file.txt;
            };
          in ''${lib.getExe pkgs.passwd2systemd-users} ${args}'')

          "${lib.getExe' pkgs.coreutils "shred"} -u ${inputDir}/passwd ${inputDir}/group"

          ":${lib.getExe pkgs.gnused} -i '$ a\\\\root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash' ${wipDir}/passwd"
          ":${lib.getExe pkgs.gnused} -i '$ a\\\\wwwrun:x:54:54:Apache httpd user:/var/empty:/run/current-system/sw/bin/bash' ${wipDir}/passwd"
          ":${lib.getExe pkgs.gnused} -i '$ a\\\\root:x:0:' ${wipDir}/group"
          ":${lib.getExe pkgs.gnused} -i '$ a\\\\wwwrun:x:54:' ${wipDir}/group"

          "+${lib.getExe' pkgs.coreutils "install"} -m644 -o root -g root -t '${outputDir}' ${wipDir}/passwd ${wipDir}/group"
          "${lib.getExe' pkgs.coreutils "shred"} -u ${wipDir}/passwd ${wipDir}/group"
        ];

        AmbientCapabilities = [ "" ];
        CapabilityBoundingSet = [ "" ];
        DeviceAllow = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
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
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SocketBindDeny = "any";
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@resources"
        ];
        UMask = "0077";

        IPAddressAllow = [
          values.hosts.microbel.ipv4
          values.hosts.microbel.ipv6
        ];
        IPAddressDeny = "any";

        RootDirectory = "/run/httpd-passwd-sync/root-mnt";
        MountAPIVFS = true;

        RuntimeDirectoryMode = "0750";
        RuntimeDirectory = [
          "httpd-passwd-sync/root-mnt"
          "httpd-passwd-sync/in"
          "httpd-passwd-sync/wip"
        ];

        BindPaths = [
          "/var/lib/httpd-passwd-sync"
        ];
        BindReadOnlyPaths = [
          builtins.storeDir
          "/etc"
          "/var/run/nscd"
        ];
      };
    };
  };
}
