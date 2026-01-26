{ config, lib, pkgs, ... }:
let
  cfg = config.services.rsync-pull-targets;
in
{
  options.services.rsync-pull-targets = {
    enable = lib.mkEnableOption "";

    rrsyncPackage = lib.mkPackageOption pkgs "rrsync" { };

    locations = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }@submoduleArgs: {
        options = {
          enable = lib.mkEnableOption "" // {
            default = true;
            example = false;
          };

          user = lib.mkOption {
            type = lib.types.str;
            description = "Which user to use as SSH login";
            example = "root";
          };

          location = lib.mkOption {
            type = lib.types.path;
            default = name;
            defaultText = lib.literalExpression "<name>";
            example = "/path/to/rsyncable/item";
          };

          # TODO: handle autogeneration of keys
          # autoGenerateSSHKeypair = lib.mkOption {
          #   type = lib.types.bool;
          #   default = config.publicKey == null;
          #   defaultText = lib.literalExpression "config.services.rsync-pull-targets.<name>.publicKey != null";
          #   example = true;
          # };

          publicKey = lib.mkOption {
            type = lib.types.str;
            # type = lib.types.nullOr lib.types.str;
            # default = null;
            example = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA comment";
          };

          rrsyncPackage = lib.mkPackageOption pkgs "rrsync" { } // {
            default = cfg.rrsyncPackage;
            defaultText = lib.literalExpression "config.services.rsync-pull-targets.rrsyncPackage";
          };

          enableRecommendedHardening = lib.mkEnableOption "a commonly used security profile for authorizedKeys attributes and rrsync args";

          rrsyncArgs = {
            ro = lib.mkEnableOption "" // {
              description = "Allow only reading from the DIR. Implies -no-del and -no-lock.";
            };
            wo = lib.mkEnableOption "" // {
              description = "Allow only writing to the DIR.";
            };
            munge = lib.mkEnableOption "" // {
              description = "Enable rsync's --munge-links on the server side.";
              # TODO: set a default?
            };
            no-del = lib.mkEnableOption "" // {
              description = "Disable rsync's --delete* and --remove* options.";
              default = submoduleArgs.config.enableRecommendedHardening;
              defaultText = lib.literalExpression "config.services.rsync-pull-targets.<name>.enableRecommendedHardening";
            };
            no-lock = lib.mkEnableOption "" // {
              description = "Avoid the single-run (per-user) lock check.";
              default = submoduleArgs.config.enableRecommendedHardening;
              defaultText = lib.literalExpression "config.services.rsync-pull-targets.<name>.enableRecommendedHardening";
            };
            no-overwrite = lib.mkEnableOption "" // {
              description = "Prevent overwriting existing files by enforcing --ignore-existing";
              default = submoduleArgs.config.enableRecommendedHardening;
              defaultText = lib.literalExpression "config.services.rsync-pull-targets.<name>.enableRecommendedHardening";
            };
          };

          authorizedKeysAttrs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = lib.optionals submoduleArgs.config.enableRecommendedHardening [
              "restrict"
              "no-agent-forwarding"
              "no-port-forwarding"
              "no-pty"
              "no-X11-forwarding"
            ];
            defaultText = lib.literalExpression ''
              lib.optionals config.services.rsync-pull-targets.<name>.enableRecommendedHardening [
                "restrict"
                "no-agent-forwarding"
                "no-port-forwarding"
                "no-pty"
                "no-X11-forwarding"
              ]
            '';
            example = [
              "restrict"
              "no-agent-forwarding"
              "no-port-forwarding"
              "no-pty"
              "no-X11-forwarding"
            ];
          };
        };
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    # assertions = lib.pipe cfg.locations [
    #   (lib.filterAttrs (_: value: value.enable))
      # TODO: assert that there are no duplicate (user, publicKey) pairs.
      #       if there are then ssh won't know which command to provide and might provide a random one, not sure.
      # (lib.mapAttrsToList (_: { user, location, publicKey, ... }: {
      #   assertion =
      #   message = "";
      # })
    # ];

    services.openssh.enable = true;
    users.users = lib.pipe cfg.locations [
      (lib.filterAttrs (_: value: value.enable))
      (lib.mapAttrs' (_: { user, location, rrsyncPackage, rrsyncArgs, authorizedKeysAttrs, publicKey, ... }: let
        rrsyncArgString = lib.cli.toCommandLineShellGNU {
          isLong = _: false;
        } rrsyncArgs;
        # TODO: handle " in location
      in {
        name = user;
        value.openssh.authorizedKeys.keys = [
          "command=\"${lib.getExe rrsyncPackage} ${rrsyncArgString} ${location}\",${lib.concatStringsSep "," authorizedKeysAttrs} ${publicKey}"
        ];
      }))
    ];
  };
}
