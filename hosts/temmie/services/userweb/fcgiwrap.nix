{ config, lib, pkgs, ... }:
let
  mcfg = config.services.pvv-userweb;
in
{
  config = lib.mkIf mcfg.enable {
    systemd.slices.system-userweb-fcgiwrap = { };

    # NOTE: expected %i here is the UID of the user
    systemd.sockets."userweb-fcgiwrap@" = {
      description = "UserWeb fcgiwrap server for user %i";
      socketConfig = {
        ListenStream = "/run/userweb-fcgiwrap/%i.sock";
        RemoveOnStop = true;

        SocketUser = "wwwrun";
        SocketGroup = "wwwrun";
        SocketMode = "0660";
      };
    };

    systemd.services."userweb-fcgiwrap@" = {
      after = [
        "httpd-passwd-sync.service"
      ];
      requires = [
        "httpd-passwd-sync.service"
      ];
      documentation = [ "man:fcgiwrap(8)" ];

      unitConfig = {
        AssertPathExists = "/run/pvvhome/by-uid/%i";
      };

      serviceConfig = {

        Slice = "system-userweb-fcgiwrap.slice";
        Type = "simple";
        User = "%i";

        ExecStart = "${lib.getExe pkgs.fcgiwrap}";

        RuntimeDirectoryMode = "0750";
        RuntimeDirectory = [
          "fcgiwrap/%i/root-mnt"
        ];
        RootDirectory = "/run/fcgiwrap/%i/root-mnt";
        MountAPIVFS = true;
        BindReadOnlyPaths = [
          builtins.storeDir
          "/etc"

          # TODO: set up minimal fake passwd + group in `ExecStartPre` instead
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
        ] ++ mcfg.fhsBindPaths;

        # TODO: handle /amd/homepvv${l}
        BindPaths = [
          "/run/pvvhome/by-uid/%i:/home/pvv"
        ];
      };
    };
  };
}
