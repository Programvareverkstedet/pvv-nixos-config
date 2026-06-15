{ config, lib, pkgs, values, ... }:
let
  mcfg = config.services.pvv-userweb;
in
{
  sops.secrets = {
    "httpd/passwd-ssh-key" = { };
    "httpd/ssh-known-hosts" = { };
  };

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
    serviceConfig = {
      User = "wwwrun";
      Group = "wwwrun";
      Slice = "system-userweb.slice";
      Restart = "on-failure";

      StandardInput = "socket";
      StandardOutput = "journal";
      StandardError = "journal";

      LoadCredential = [
        "sshkey:${config.sops.secrets."httpd/passwd-ssh-key".path}"
        "ssh-known-hosts:${config.sops.secrets."httpd/ssh-known-hosts".path}"
      ];
      ExecStartPre = let
        rsyncArgs = lib.cli.toCommandLineShellGNU { } {
          archive = true;
          verbose = true;
          compress = true;
          rsh = "${lib.getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o UserKnownHostsFile=%d/ssh-known-hosts -i %d/sshkey";
        };
        inputDir = "/run/httpd-log-processor-%i/pamunix-in";
        outputDir = "/run/httpd-log-processor-%i/pamunix-out";
      in lib.mkForce [
        "${lib.getExe pkgs.rsync} ${rsyncArgs} pvv@smtp.pvv.ntnu.no:/etc/passwd ${inputDir}/"
        "${lib.getExe pkgs.rsync} ${rsyncArgs} pvv@smtp.pvv.ntnu.no:/etc/group ${inputDir}/"

        (let
          args = lib.cli.toCommandLineShellGNU { } {
            passwd-file = "${inputDir}/passwd";
            group-file = "${inputDir}/group";
            output-dir = outputDir;
            shadow-file = pkgs.emptyFile;

            output-passwd = true;

            ignore-user-file = toString ./ignore_user_file.txt;
            ignore-group-file = toString ./ignore_group_file.txt;
          };
        in ''${lib.getExe pkgs.passwd2systemd-users} ${args}'')
        "${lib.getExe' pkgs.coreutils "shred"} -u ${inputDir}/passwd ${inputDir}/group"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash' ${outputDir}/passwd"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\wwwrun:x:54:54:Apache httpd user:/var/empty:/run/current-system/sw/bin/bash' ${outputDir}/passwd"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\root:x:0:' ${outputDir}/group"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\wwwrun:x:54:' ${outputDir}/group"
        "+${lib.getExe' pkgs.coreutils "chown"} root:root ${outputDir}/passwd ${outputDir}/group"
        "+${lib.getExe' pkgs.coreutils "chmod"} 0644 ${outputDir}/passwd ${outputDir}/group"
        "+${lib.getExe pkgs.mount} --bind ${outputDir}/passwd /etc/passwd"
        "+${lib.getExe pkgs.mount} --bind ${outputDir}/group  /etc/group"
      ];

      ExecStart = "${lib.getExe mcfg.apacheLogProcessorPackage} %i";

      AmbientCapabilities = [ "CAP_SETUID" "CAP_SETGID" ];
      CapabilityBoundingSet = [ "CAP_SETUID" "CAP_SETGID" ];
      DeviceAllow = [ "" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      PrivateDevices = true;
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
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
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

      IPAddressAllow = [
        "127.0.0.53" # systemd-resolved
        values.hosts.microbel.ipv4
        values.hosts.microbel.ipv6
      ];
      IPAddressDeny = "any";

      RootDirectory = "/run/httpd-log-processor-%i/root-mnt";
      MountAPIVFS = true;

      RuntimeDirectoryMode = "0750";
      RuntimeDirectory = [
        "httpd-log-processor-%i/root-mnt"
        "httpd-log-processor-%i/pamunix-in"
        "httpd-log-processor-%i/pamunix-out"
      ];
      BindReadOnlyPaths = [
        builtins.storeDir
        "/etc"
        "/etc/resolv.conf"

        "-/run/httpd-log-processor-%i/pamunix-out/passwd:/etc/passwd"
        "-/run/httpd-log-processor-%i/pamunix-out/group:/etc/group"

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
