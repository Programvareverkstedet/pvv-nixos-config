{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.emergency-access-ramdisk;
in
{
  imports = [ ./image.nix ];

  options.services.emergency-access-ramdisk = {
    enable = lib.mkEnableOption "an SSH daemon running from a ramfs, for emergency access";

    port = lib.mkOption {
      description = "Port for the emergency SSH daemon.";
      type = lib.types.port;
      default = 22222;
    };

    mountPoint = lib.mkOption {
      description = "Where to mount the ramfs.";
      type = lib.types.path;
      default = "/run/emergency-access-ramdisk";
    };

    sshPackage = lib.mkOption {
      description = "Statically linked OpenSSH package to run in the ramdisk.";
      type = lib.types.package;

      # NOTE: setting `dropbear` here might require you to change the ssh config and `ExecStart` flags.
      example = lib.literalExpression "pkgs.pkgsStatic.dropbear";

      # Yeet a bunch of binaries, since every one of them contains a big fat copy of OpenSSL.
      default = pkgs.pkgsStatic.openssh.overrideAttrs (prev: {
        postInstall = (prev.postInstall or "") + ''
          rm $out/bin/{ssh-add,ssh-agent,ssh-copy-id,ssh-keygen,ssh-keyscan}
          rm $out/libexec/{sftp-server,ssh-keysign,ssh-pkcs11-helper,ssh-sk-helper}
        '';
      });
    };

    authorizedKeys = lib.mkOption {
      description = "SSH public keys allowed to log in as root to the emergency ramdisk.";
      type = lib.types.listOf lib.types.singleLineStr;

      # TODO: This reduces the "SSH KEY + PW" requirement to just "SSH KEY" for root access.
      #       Let's not do that or something, idk, create a specific emergency key.
      default = config.users.users.root.openssh.authorizedKeys.keys
        ++ lib.concatMap
          (user: user.openssh.authorizedKeys.keys)
          (lib.filter (user: lib.elem "wheel" user.extraGroups) (lib.attrValues config.users.users));
    };

    hostKeys = lib.mkOption {
      description = ''
        OpenSSH host keys to copy into the ramdisk.

        Note that this will happen when the service starts, not when the image is built.
        If the keys are not present when starting the service, the service might become inaccessible.
      '';
      type = with lib.types; listOf path;
      default = map (key: key.path) config.services.openssh.hostKeys;
      example = [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.authorizedKeys != [ ];
        message = "services.emergency-access-ramdisk: no authorized keys, nobody would be able to log in";
      }
      {
        assertion = cfg.hostKeys != [ ];
        message = "services.emergency-access-ramdisk: no host keys";
      }
    ];

    fileSystems.${cfg.mountPoint} = {
      # NOTE: tmpfs can be swapped out to disks, so ramfs is better here.
      device = "ramfs";
      fsType = "ramfs";
      options = [ "mode=0700" ];
    };

    systemd.services.emergency-access-ramdisk-populate = {
      description = "Populate the emergency access ramdisk";

      after = [ "sshd-keygen.service" ];
      wants = [ "sshd-keygen.service" ];
      unitConfig = {
        RequiresMountsFor = [ cfg.mountPoint ];
        # For `mount --beneath`
        AssertKernelVersion = ">=6.5";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStart = let
          populate = pkgs.writeShellApplication {
            name = "emergency-access-ramdisk-populate";
            runtimeInputs = with pkgs; [
              coreutils
              util-linux
            ];
            text = builtins.readFile ./populate.sh;
          };
        in "${lib.getExe populate} ${lib.escapeShellArgs ([ cfg.mountPoint cfg.image ] ++ cfg.hostKeys)}";

        # NOTE: The mounts made here have to be visible to the rest of the system, so anything that
        #       gives the service its own mount namespace (ProtectSystem, PrivateTmp, RootDirectory,
        #       confinement, ...) can't be used.
        PrivateMounts = false;
        CapabilityBoundingSet = [ "CAP_SYS_ADMIN" ];
        NoNewPrivileges = true;
        PrivateNetwork = true;
        IPAddressDeny = "any";
        RestrictAddressFamilies = [ "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "@mount"
        ];
      };
    };

    systemd.services.emergency-access-ramdisk-sshd = {
      description = "Emergency access SSH daemon running from a ramfs";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "emergency-access-ramdisk-populate.service"
      ];
      requires = [ "emergency-access-ramdisk-populate.service" ];

      # Keep active sessions alive across rebuilds
      stopIfChanged = false;

      serviceConfig = {
        ExecStart = "${cfg.sshPackage}/bin/sshd -D -e -f /etc/ssh/sshd_config";

        Restart = "always";
        RestartSec = 5;
        KillMode = "process";

        RootDirectory = cfg.mountPoint;
        MountAPIVFS = true;
        BindPaths = [ "/:/host" ];

        # Bypass journald, which might be stuck writing to disk or something
        StandardOutput = "file:/dev/kmsg";
        StandardError = "file:/dev/kmsg";

        # Never swap to disk, and don't let the OOM(ndeman) kill us.
        OOMScoreAdjust = -1000;
        MemorySwapMax = 0;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
