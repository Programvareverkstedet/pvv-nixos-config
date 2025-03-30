{ config, pkgs, lib, utils, ... }:
let
  cfg = config.services.gickup;
  format = pkgs.formats.yaml { };
in
{
  imports = [
    ./set-description.nix
    ./hardlink-files.nix
    ./import-from-toml.nix
    ./update-linktree.nix
  ];

  options.services.gickup = {
    enable = lib.mkEnableOption "gickup, a git repository mirroring service";

    package = lib.mkPackageOption pkgs "gickup" { };
    gitPackage = lib.mkPackageOption pkgs "git" { };
    gitLfsPackage = lib.mkPackageOption pkgs "git-lfs" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      description = "The directory to mirror repositories to.";
      default = "/var/lib/gickup";
      example = "/data/gickup";
    };

    destinationSettings = lib.mkOption {
      description = ''
        Settings for destination local, see gickup configuration file

        Note that `path` will be set automatically to `/var/lib/gickup`
      '';
      type = lib.types.submodule {
        freeformType = format.type;
      };
      default = { };
      example = {
        structured = true;
        zip = false;
        keep = 10;
        bare = true;
        lfs = true;
      };
    };

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (submoduleInputs@{ name, ... }: let
        submoduleName = name;

        nameParts = rec {
          repoType = builtins.head (lib.splitString ":" submoduleName);

          owner = if repoType == "any"
                  then null
                  else lib.pipe submoduleName [
                    (lib.removePrefix "${repoType}:")
                    (lib.splitString "/")
                    builtins.head
                  ];

          repo = if repoType == "any"
                 then null
                 else lib.pipe submoduleName [
                    (lib.removePrefix "${repoType}:")
                    (lib.splitString "/")
                    lib.last
                  ];

          slug = if repoType == "any"
                 then lib.toLower (builtins.replaceStrings [ ":" "/" ] [ "-" "-" ] submoduleName)
                 else "${lib.toLower repoType}-${lib.toLower owner}-${lib.toLower repo}";
        };
      in {
        options = {
          interval = lib.mkOption {
            type = lib.types.str;
            default = "daily";
            example = "weekly";
            description = ''
              Specification (in the format described by {manpage}`systemd.time(7)`) of the time
              interval at which to run the service.
            '';
          };

          type = lib.mkOption {
            type = lib.types.enum [
              "github"
              "gitlab"
              "gitea"
              "gogs"
              "bitbucket"
              "onedev"
              "sourcehut"
              "any"
            ];
            example = "github";
            default = nameParts.repoType;
            description = ''
              The type of the repository to mirror.
            '';
          };

          owner = lib.mkOption {
            type = with lib.types; nullOr str;
            example = "go-gitea";
            default = nameParts.owner;
            description = ''
              The owner of the repository to mirror (if applicable)
            '';
          };

          repo = lib.mkOption {
            type = with lib.types; nullOr str;
            example = "gitea";
            default = nameParts.repo;
            description = ''
              The name of the repository to mirror (if applicable)
            '';
          };

          slug = lib.mkOption {
            type = lib.types.str;
            default = nameParts.slug;
            example = "github-go-gitea-gitea";
            description = ''
              The slug of the repository to mirror.
            '';
          };

          description = lib.mkOption {
            type = with lib.types; nullOr str;
            example = "A project which does this and that";
            description = ''
              A description of the project. This isn't used directly by gickup for anything,
              but can be useful if gickup is used together with cgit or similar.
            '';
          };

          settings = lib.mkOption {
            description = "Instance specific settings, see gickup configuration file";
            type = lib.types.submodule {
              freeformType = format.type;
            };
            default = { };
            example = {
              username = "gickup";
              password = "hunter2";
              wiki = true;
              issues = true;
            };
          };
        };
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.gickup = {
      isSystemUser = true;
      group = "gickup";
      home = "/var/lib/gickup";
    };

    users.groups.gickup = { };

    services.gickup.destinationSettings.path = "/var/lib/gickup/raw";

    systemd.tmpfiles.settings."10-gickup" = lib.mkIf (cfg.dataDir != "/var/lib/gickup") {
      ${cfg.dataDir}.d = {
        user = "gickup";
        group = "gickup";
        mode = "0755";
      };
    };

    systemd.slices."system-gickup" = {
      description = "Gickup git repository mirroring service";
      after = [ "network.target" ];
    };

    systemd.targets.gickup = {
      description = "Gickup git repository mirroring service";
      wants = map ({ slug, ... }: "gickup@${slug}.service") (lib.attrValues cfg.instances);
    };

    systemd.timers = {
      "gickup@" = {
        description = "Gickup git repository mirroring service for %i";

        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
          AccuracySec = "1s";
        };
      };
    }
    //
    # Overrides for mirrors which are not "daily"
    (lib.pipe cfg.instances [
      builtins.attrValues
      (builtins.filter (instance: instance.interval != "daily"))
      (map ({ slug, interval, ... }: {
        name = "gickup@${slug}";
        value = {
          overrideStrategy = "asDropin";
          timerConfig.OnCalendar = interval;
        };
      }))
      builtins.listToAttrs
    ]);

    systemd.targets.timers.wants = map ({ slug, ... }: "gickup@${slug}.timer") (lib.attrValues cfg.instances);

    systemd.services = {
      "gickup@" = let
        configDir = lib.pipe cfg.instances [
          (lib.mapAttrsToList (name: instance: {
            name = "${instance.slug}.yml";
            path = format.generate "gickup-configuration-${name}.yml" {
              destination.local = [ cfg.destinationSettings ];
              source.${instance.type} = [
                (
                  (lib.optionalAttrs (instance.type != "any") {
                    user = instance.owner;
                    includeorgs = [ instance.owner ];
                    include = [ instance.repo ];
                  })
                  //
                  instance.settings
                )
              ];
            };
          }))
          (pkgs.linkFarm "gickup-configuration-files")
        ];
      in {
        description = "Gickup git repository mirroring service for %i";
        after = [ "network.target" ];

        path = [
          cfg.gitPackage
          cfg.gitLfsPackage
        ];

        restartIfChanged = false;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "'${pkgs.gickup}/bin/gickup' '${configDir}/%i.yml'";
          ExecStartPost = "";

          User = "gickup";
          Group = "gickup";

          BindPaths = lib.optionals (cfg.dataDir != "/var/lib/gickup") [
            "${cfg.dataDir}:/var/lib/gickup"
          ];

          Slice = "system-gickup.slice";

          SyslogIdentifier = "gickup-%i";
          StateDirectory = "gickup";
          # WorkingDirectory = "gickup";
          # RuntimeDirectory = "gickup";
          # RuntimeDirectoryMode = "0700";

          # https://discourse.nixos.org/t/how-to-prevent-custom-systemd-service-from-restarting-on-nixos-rebuild-switch/43431
          RemainAfterExit = true;

          # Hardening options
          AmbientCapabilities = [];
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateMounts = true;
          PrivateTmp = true;
          PrivateUsers = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          # ProtectProc = "invisible";
          # ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          # SystemCallFilter = [
          #   "@system-service"
          #   "~@resources"
          #   "~@privileged"
          # ];
          UMask = "0002";
          CapabilityBoundingSet = [];
        };
      };
    };
  };
}
