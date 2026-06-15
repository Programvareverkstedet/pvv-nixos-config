{ config, lib, pkgs, ... }:
{
  services.postfix.enable = lib.mkForce false;

  services.nullmailer = {
    enable = true;
    config = {
      me = config.networking.fqdn;
      remotes = "mail.pvv.ntnu.no smtp --port=25";
    };
  };

  services.bro = {
    enable = true;

    instances.userweb-sendmail = {
      enable = true;

      client = {
        settings.BRO_FILE_FLAGS = [
          "-C"
        ];
      };

      server = {
        settings = {
          executable = let
            sendmailWrapper = pkgs.writeShellApplication {
              name = "sendmail";
              runtimeInputs = [ ];
              bashOptions = [
                "errexit"
                "pipefail"
              ];
              text = ''
                args=("$@")

                if [[ -z "$USERDIR_USER" ]] && [[ "$USERDIR_USER" != "pvv" ]]; then
                    # Prepend -fusername to the argument list, so bounces go to the user
                    args=("-f$USERDIR_USER" "''${args[@]}")
                fi

                exec '${lib.getExe pkgs.system-sendmail}' -t -i "''${args[@]}"
              '';
            };
          in lib.getExe sendmailWrapper;
          allowed-env = [ "USERDIR_USER" ];
        };
      };
    };
  };

  environment.systemPackages = [
    (config.services.bro.instances.userweb-sendmail.client.package.overrideAttrs (prev: {
      buildCommand = prev.buildCommand + ''
        mv "$out/bin/sendmail" "$out/bin/bro-sendmail"
      '';
    }))
  ];

  users.users.nullmailer-user = {
    enable = true;
    isSystemUser = true;
    group = "nullmailer-user";
  };

  users.groups.nullmailer-user = { };

  systemd.services.bro-userweb-sendmail = {
    serviceConfig = {
      User = "nullmailer-user";
      Group = "nullmailer-user";
      Slice = "system-userweb.slice";

      ReadWritePaths = [
        "/var/spool/nullmailer"
      ];

      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      NoNewPrivileges = false;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = false;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      PrivateMounts = true;
      ProcSubset = "pid";
      ProtectProc = "invisible";
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@resources"
      ];
      UMask = "0077";
    };
  };

  systemd.services.httpd.serviceConfig = {
    BindPaths = [ (lib.head config.systemd.sockets.bro-userweb-sendmail.listenStreams) ];
  };
}
