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
  options.services.emergency-access-ramdisk = {
    shell = lib.mkPackageOption pkgs.pkgsStatic "bashInteractive" { };

    packages = lib.mkOption {
      description = ''
        Packages to include in the ramdisk, keyed by name. Everything included lives in RAM,
        so prefer statically linked packages from `pkgs.pkgsStatic`.
      '';
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkEnableOption "this package in the ramdisk" // { default = true; };

          package = lib.mkOption {
            description = "The package to include.";
            type = lib.types.package;
            default = pkgs.pkgsStatic.${name};
            defaultText = lib.literalExpression "pkgs.pkgsStatic.<name>";
          };

          binaries = lib.mkOption {
            description = ''
              If set, only copy these binaries out of the package's `/bin`, without any of its references.

              This is useful for packages with lots of tools, or with references to build-time dependencies.
            '';
            type = with lib.types; nullOr (listOf str);
            default = null;
            example = [ "lsblk" "findmnt" ];
          };

          priority = lib.mkOption {
            description = ''
              Priority of the package' files when merged with other packages that provides a binary with the same name.
              Lower values take precedence, as with `meta.priority`.
            '';
            type = lib.types.int;
            default = 5;
          };
        };
      }));
      default = { };
      example = lib.literalExpression ''
        {
          tmux.enable = false;
          util-linux.binaries = [ "lsblk" ];
          strace.package = pkgs.pkgsStatic.strace;
        }
      '';
    };

    files = lib.mkOption {
      description = ''
        Files to include in the image, keyed by their path relative to `/`.
      '';
      type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
        options = {
          enable = lib.mkEnableOption "this file in the image" // { default = true; };

          text = lib.mkOption {
            description = "Contents of the file.";
            type = with lib.types; nullOr lines;
            default = null;
          };

          source = lib.mkOption {
            description = "Path of the source file.";
            type = lib.types.path;
          };

          mode = lib.mkOption {
            description = "Permissions of the file.";
            type = lib.types.str;
            default = "0644";
          };
        };

        config.source = lib.mkIf (config.text != null) (lib.mkDefault (
          pkgs.writeText "emergency-access-ramdisk-${lib.replaceStrings [ "/" ] [ "-" ] name}" config.text
        ));
      }));
      default = { };
      example = {
        "etc/hosts".text = "127.0.0.1 localhost";
      };
    };

    sshdSettings = lib.mkOption {
      description = ''
        Configuration for the emergency SSH daemon, see {manpage}`sshd_config(5)`.

        Lists are rendered as one line per element.
      '';
      type = lib.types.submodule {
        freeformType = with lib.types; attrsOf (oneOf [ bool int str (listOf str) ]);
      };
      default = { };
      example = {
        LogLevel = "VERBOSE";
      };
    };

    mkfsErofsFlags = lib.mkOption {
      description = ''
        Extra flags for {manpage}`mkfs.erofs(1)`, mainly to tune compression.

        `--all-root`, `-T0` and `-Uclear` are always passed, to keep the image reproducible.
      '';
      type = with lib.types; listOf str;
      # NOTE: check the kernel options before going wild here, I tried to use zstd15 but
      #       the default NixOS kernels do not seem to support that.
      default = [
        "-zlz4hc"
        "-Eztailpacking,fragments"
      ];
      example = [
        "-zzstd,15"
        "-Eztailpacking,fragments,dedupe"
      ];
    };

    image = lib.mkOption {
      description = ''
        The read-only part of the ramdisk as an EROFS image, to be copied into and mounted
        within {option}`mountPoint`.

        This image can be reused on other distros.
      '';
      type = lib.types.package;
      readOnly = true;
    };
  };

  config = {
    services.emergency-access-ramdisk.packages = let
      hasFilesystem = type: lib.any (fs: fs.fsType == type) (lib.attrValues config.fileSystems);
    in lib.mapAttrs (_: binaries: { binaries = lib.mkDefault binaries; }) ({
      tmux = [ "tmux" ];
      gptfdisk = [ "sgdisk" "gdisk" ];
      util-linux = [ "lsblk" "findmnt" "wipefs" "sfdisk" ];
      smartmontools = [ "smartctl" ];
    }
    // lib.optionalAttrs (hasFilesystem "btrfs") { btrfs-progs = [ "btrfs" ]; }
    // lib.optionalAttrs (hasFilesystem "ext4") { e2fsprogs = [ "e2fsck" "debugfs" ]; }
    // lib.optionalAttrs (hasFilesystem "vfat") { dosfstools = [ "fsck.fat" ]; }
    // lib.optionalAttrs (hasFilesystem "exfat") { exfatprogs = [ "fsck.exfat" ]; }
    // lib.optionalAttrs (lib.any hasFilesystem [ "ntfs" "ntfs3" "ntfs-3g" ]) { ntfs3g = [ "ntfsfix" ]; })
    // {
      # Any package containing a binary with a nameclash for a busybox binary
      # likely has a better implementation, so give it higher prio when merging.
      busybox.priority = lib.mkDefault 10;
    };

    services.emergency-access-ramdisk.sshdSettings = lib.mapAttrs (_: lib.mkDefault) {
      PermitRootLogin = "prohibit-password";
      AuthenticationMethods = "publickey";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthorizedKeysFile = "/etc/ssh/authorized_keys";

      SetEnv = "PATH=/bin";
      AcceptEnv = "LANG LC_* COLORTERM";

      # TODO: automatically fix this if we are using dropbear.
      Subsystem = "sftp internal-sftp";

      PidFile = "none";
      UseDNS = false;
      PrintMotd = true;
      PrintLastLog = false;
    } // {
      Port = cfg.port;
      HostKey = map (key: "/host-keys/${baseNameOf key}") cfg.hostKeys;
    };

    services.emergency-access-ramdisk.files = {
      # The host's sshd user does not have a fixed uid, so the privilege separation user borrows nobody's
      "etc/passwd".text = ''
        root:x:0:0:root:/root:/bin/${baseNameOf (lib.getExe cfg.shell)}
        sshd:x:65534:65534:sshd privilege separation:/var/empty:/bin/false
      '';

      "etc/group".text = ''
        root:x:0:
        sshd:x:65534:
      '';

      "etc/profile".text = ''
        export PATH=/bin
        export PS1='\[\e[1;31m\][emergency@\h:\w]\$\[\e[0m\] '
      '';

      "etc/motd".text = lib.mkDefault ''
        You are in the emergency access ramdisk.
        The real root filesystem is mounted at /host, but touching it may hang if the disks are dead.
        Mounts done here are private to this namespace, use 'on-host' to run commands in the host's.
      '';

      "etc/ssh/sshd_config".text = let
        render = value: if lib.isBool value then lib.boolToYesNo value else toString value;
      in lib.concatLines (lib.concatLists (lib.mapAttrsToList (key: value:
        map (v: "${key} ${render v}") (lib.toList value)
      ) cfg.sshdSettings));

      "etc/ssh/authorized_keys".text = lib.concatLines cfg.authorizedKeys;
    };

    services.emergency-access-ramdisk.image = let
      terminfo = "${pkgs.pkgsStatic.ncurses}/share/terminfo";

      # NOTE: pkgsStatic, so that the shebang points to a static bash rather than one linked against glibc
      onHost = pkgs.pkgsStatic.writeShellApplication {
        name = "on-host";
        runtimeEnv = {
          MOUNTPOINT = cfg.mountPoint;
          TERMINFO_DIR = terminfo;
        };
        text = builtins.readFile ./on-host.sh;
      };

      # Copy only some binaries out of a package, without any of its references
      extractBinaries = name: package: bins: pkgs.runCommand "emergency-access-ramdisk-${name}" {
        nativeBuildInputs = [ pkgs.nukeReferences ];
      } ''
        mkdir -p $out/bin
        ${lib.concatMapStringsSep "\n" (bin: "cp -L ${lib.getExe' package bin} $out/bin/") bins}
        nuke-refs $out/bin/*
      '';

      packages = lib.mapAttrsToList (name: entry:
        lib.setPrio entry.priority (
          if entry.binaries == null
          then entry.package
          else extractBinaries name entry.package entry.binaries
        )
      ) (lib.filterAttrs (_: entry: entry.enable) cfg.packages);

      # Supports mount --beneath, which is used to atomically swap the image when updating
      mount = extractBinaries "mount" pkgs.pkgsStatic.util-linux [ "mount" "umount" ];

      binEnv = pkgs.buildEnv {
        name = "emergency-access-ramdisk-bin";
        paths = [
          (lib.hiPrio cfg.shell)
          (lib.hiPrio mount)
          cfg.sshPackage
          onHost
        ]
        ++ packages;
        pathsToLink = [ "/bin" ];
      };

      closure = pkgs.writeClosure [
        binEnv
        pkgs.pkgsStatic.ncurses
      ];
      files = lib.filterAttrs (_: file: file.enable) cfg.files;
    in pkgs.runCommand "emergency-access-ramdisk.erofs" {
      nativeBuildInputs = [ pkgs.erofs-utils ];

      __structuredAttrs = true;
      FILE_SOURCES = lib.mapAttrs (_: file: "${file.source}") files;
      FILE_MODES = lib.mapAttrs (_: file: file.mode) files;
      MKFS_EROFS_FLAGS = cfg.mkfsErofsFlags;
    } ''
      ROOT=$PWD/root

      declare -ar DIRECTORIES=(
        etc
        host-bin
        nix/store
        usr/share
        var/empty
      )
      mkdir -p "''${DIRECTORIES[@]/#/$ROOT/}"

      xargs cp -a -t "$ROOT/nix/store" < '${closure}'

      for DIR in bin sbin usr/bin usr/sbin; do
        ln -s '${binEnv}/bin' "$ROOT/$DIR"
      done
      ln -s '${terminfo}' "$ROOT/usr/share/terminfo"

      for FILE in "''${!FILE_SOURCES[@]}"; do
        install -Dm"''${FILE_MODES[$FILE]}" "''${FILE_SOURCES[$FILE]}" "$ROOT/$FILE"
      done

      # If we need to run the tools located on ramdisk in the host mount namespace, these symlinks should
      # help us do so. The `on-host` script sets its PATH accordingly.
      for TOOL in ${binEnv}/bin/*; do
        ln -s '${cfg.mountPoint}'"$(readlink -f "$TOOL")" "$ROOT/host-bin/$(basename "$TOOL")"
      done

      mkfs.erofs "''${MKFS_EROFS_FLAGS[@]}" --all-root -T0 -Uclear "$out" "$ROOT"
    '';
  };
}
