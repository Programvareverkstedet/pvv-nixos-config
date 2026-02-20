{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.bluemap;
  format = pkgs.formats.hocon { };

  coreConfig = format.generate "core.conf" cfg.coreSettings;
  webappConfig = format.generate "webapp.conf" cfg.webappSettings;
  webserverConfig = format.generate "webserver.conf" cfg.webserverSettings;

  storageFolder = pkgs.linkFarm "storage" (
    lib.attrsets.mapAttrs' (
      name: value: lib.nameValuePair "${name}.conf" (format.generate "${name}.conf" value)
    ) cfg.storage
  );

  generateMapConfigWithMarkerData =
    name:
    { extraHoconMarkersFile, settings, ... }:
    assert (extraHoconMarkersFile == null) != ((settings.marker-sets or { }) == { });
    lib.pipe settings (
      (lib.optionals (extraHoconMarkersFile != null) [
        (
          settings:
          lib.recursiveUpdate settings {
            marker-placeholder = "###ASDF###";
          }
        )
      ])
      ++ [
        (format.generate "${name}.conf")
      ]
      ++ (lib.optionals (extraHoconMarkersFile != null) [
        (
          hoconFile:
          pkgs.runCommand "${name}-patched.conf" { } ''
            mkdir -p "$(dirname "$out")"
            cp '${hoconFile}' "$out"
            substituteInPlace "$out" \
              --replace-fail '"marker-placeholder" = "###ASDF###"' "\"marker-sets\" = $(cat '${extraHoconMarkersFile}')"
          ''
        )
      ])
    );

  mapsFolder = lib.pipe cfg.maps [
    (lib.attrsets.mapAttrs' (
      name: value: {
        name = "${name}.conf";
        value = generateMapConfigWithMarkerData name value;
      }
    ))
    (pkgs.linkFarm "maps")
  ];

  webappConfigFolder = pkgs.linkFarm "bluemap-config" {
    "maps" = mapsFolder;
    "storages" = storageFolder;
    "core.conf" = coreConfig;
    "webapp.conf" = webappConfig;
    "webserver.conf" = webserverConfig;
    "packs" = cfg.packs;
  };

  renderConfigFolder =
    name: value:
    pkgs.linkFarm "bluemap-${name}-config" {
      "maps" = pkgs.linkFarm "maps" {
        "${name}.conf" = generateMapConfigWithMarkerData name value;
      };
      "storages" = storageFolder;
      "core.conf" = coreConfig;
      "webapp.conf" = format.generate "webapp.conf" (
        cfg.webappSettings // { "update-settings-file" = false; }
      );
      "webserver.conf" = webserverConfig;
      "packs" = value.packs;
    };

  inherit (lib) mkOption;
in
{
  options.services.bluemap = {
    enable = lib.mkEnableOption "bluemap";
    package = lib.mkPackageOption pkgs "bluemap" { };

    eula = mkOption {
      type = lib.types.bool;
      description = ''
        By changing this option to true you confirm that you own a copy of minecraft Java Edition,
        and that you agree to minecrafts EULA.
      '';
      default = false;
    };

    defaultWorld = mkOption {
      type = lib.types.path;
      description = ''
        The world used by the default map ruleset.
        If you configure your own maps you do not need to set this.
      '';
      example = lib.literalExpression "\${config.services.minecraft.dataDir}/world";
    };

    enableRender = mkOption {
      type = lib.types.bool;
      description = "Enable rendering";
      default = true;
    };

    webRoot = mkOption {
      type = lib.types.path;
      default = "/var/lib/bluemap/web";
      description = "The directory for saving and serving the webapp and the maps";
    };

    enableNginx = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable configuring a virtualHost for serving the bluemap webapp";
    };

    host = mkOption {
      type = lib.types.str;
      default = "bluemap.${config.networking.domain}";
      defaultText = lib.literalExpression "bluemap.\${config.networking.domain}";
      description = "Domain to configure nginx for";
    };

    onCalendar = mkOption {
      type = lib.types.str;
      description = ''
        How often to trigger rendering the map,
        in the format of a systemd timer onCalendar configuration.
        See {manpage}`systemd.timer(5)`.
      '';
      default = "*-*-* 03:10:00";
    };

    coreSettings = mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          data = mkOption {
            type = lib.types.path;
            description = "Folder for where bluemap stores its data";
            default = "/var/lib/bluemap";
          };
          metrics = lib.mkEnableOption "Sending usage metrics containing the version of bluemap in use";
        };
      };
      description = "Settings for the core.conf file, [see upstream docs](https://github.com/BlueMap-Minecraft/BlueMap/blob/master/common/src/main/resources/de/bluecolored/bluemap/config/core.conf).";
    };

    webappSettings = mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
      default = {
        enabled = true;
        webroot = cfg.webRoot;
      };
      defaultText = lib.literalExpression ''
        {
          enabled = true;
          webroot = config.services.bluemap.webRoot;
        }
      '';
      description = "Settings for the webapp.conf file, see [upstream docs](https://github.com/BlueMap-Minecraft/BlueMap/blob/master/common/src/main/resources/de/bluecolored/bluemap/config/webapp.conf).";
    };

    webserverSettings = mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          enabled = mkOption {
            type = lib.types.bool;
            description = ''
              Enable bluemap's built-in webserver.
              Disabled by default in nixos for use of nginx directly.
            '';
            default = false;
          };
        };
      };
      default = { };
      description = ''
        Settings for the webserver.conf file, usually not required.
        [See upstream docs](https://github.com/BlueMap-Minecraft/BlueMap/blob/master/common/src/main/resources/de/bluecolored/bluemap/config/webserver.conf).
      '';
    };

    maps = mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              packs = mkOption {
                type = lib.types.path;
                default = cfg.packs;
                defaultText = lib.literalExpression "config.services.bluemap.packs";
                description = "A set of resourcepacks, datapacks, and mods to extract resources from, loaded in alphabetical order.";
              };

              extraHoconMarkersFile = mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = ''
                  Path to a hocon file containing marker data.
                  The content of this file will be injected into the map config file in a separate derivation.

                  DO NOT SEND THIS TO NIXPKGS, IT'S AN UGLY HACK.
                '';
              };

              settings = mkOption {
                type = (
                  lib.types.submodule {
                    freeformType = format.type;
                    options = {
                      world = mkOption {
                        type = lib.types.path;
                        description = "Path to world folder containing the dimension to render";
                      };
                      name = mkOption {
                        type = lib.types.str;
                        description = "The display name of this map (how this map will be named on the webapp)";
                        default = name;
                        defaultText = lib.literalExpression "<name>";
                      };
                      render-mask = mkOption {
                        type = with lib.types; listOf (attrsOf format.type);
                        description = "Limits for the map render";
                        default = [ ];
                        example = [
                          {
                            min-x = -4000;
                            max-x = 4000;
                            min-z = -4000;
                            max-z = 4000;
                            min-y = 50;
                            max-y = 100;
                          }
                          {
                            subtract = true;
                            min-y = 90;
                            max-y = 127;
                          }
                        ];
                      };
                    };
                  }
                );
                description = ''
                  Settings for files in `maps/`.
                  See the default for an example with good options for the different world types.
                  For valid values [consult upstream docs](https://github.com/BlueMap-Minecraft/BlueMap/blob/master/common/src/main/resources/de/bluecolored/bluemap/config/maps/map.conf).
                '';
              };
            };
          }
        )
      );
      default = {
        "overworld".settings = {
          world = cfg.defaultWorld;
          dimension = "minecraft:overworld";
          name = "Overworld";
          ambient-light = 0.1;
          cave-detection-ocean-floor = -5;
        };

        "nether".settings = {
          world = cfg.defaultWorld;
          dimension = "minecraft:the_nether";
          name = "Nether";
          sorting = 100;
          sky-color = "#290000";
          void-color = "#150000";
          sky-light = 1;
          ambient-light = 0.6;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
          cave-detection-uses-block-light = true;
        };

        "end".settings = {
          world = cfg.defaultWorld;
          dimension = "minecraft:the_end";
          name = "The End";
          sorting = 200;
          sky-color = "#080010";
          void-color = "#080010";
          sky-light = 1;
          ambient-light = 0.6;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
        };
      };
      defaultText = lib.literalExpression ''
        {
          "overworld".settings = {
            world = cfg.defaultWorld;
            name = "Overworld";
            dimension = "minecraft:overworld";
            ambient-light = 0.1;
            cave-detection-ocean-floor = -5;
          };

          "nether".settings = {
            world = cfg.defaultWorld;
            dimension = "minecraft:the_nether";
            name = "Nether";
            sorting = 100;
            sky-color = "#290000";
            void-color = "#150000";
            sky-light = 1;
            ambient-light = 0.6;
            remove-caves-below-y = -10000;
            cave-detection-ocean-floor = -5;
            cave-detection-uses-block-light = true;
          };

          "end".settings = {
            world = cfg.defaultWorld;
            name = "The End";
            dimension = "minecraft:the_end";
            sorting = 200;
            sky-color = "#080010";
            void-color = "#080010";
            sky-light = 1;
            ambient-light = 0.6;
            remove-caves-below-y = -10000;
            cave-detection-ocean-floor = -5;
          };
        };
      '';
      description = ''
        map-specific configuration.
        These correspond to views in the webapp and are usually
        different dimension of a world or different render settings of the same dimension.
        If you set anything in this option you must configure all dimensions yourself!
      '';
    };

    storage = mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType = format.type;
          options = {
            storage-type = mkOption {
              type = lib.types.enum [
                "FILE"
                "SQL"
              ];
              description = "Type of storage config";
              default = "FILE";
            };
          };
        }
      );
      description = ''
        Where the rendered map will be stored.
        Unless you are doing something advanced you should probably leave this alone and configure webRoot instead.
        [See upstream docs](https://github.com/BlueMap-Minecraft/BlueMap/tree/master/common/src/main/resources/de/bluecolored/bluemap/config/storages)
      '';
      default = {
        "file" = {
          root = "${cfg.webRoot}/maps";
        };
      };
      defaultText = lib.literalExpression ''
        {
          "file" = {
            root = "''${config.services.bluemap.webRoot}/maps";
          };
        }
      '';
    };

    packs = mkOption {
      type = lib.types.path;
      default = pkgs.linkFarm "packs" { };
      description = ''
        A set of resourcepacks, datapacks, and mods to extract resources from, loaded in alphabetical order.
        Can be overriden on a per-map basis with `services.bluemap.maps.<name>.packs`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.bluemap.eula;
        message = ''
          You have enabled bluemap but have not accepted minecraft's EULA.
          You can achieve this through setting `services.bluemap.eula = true`
        '';
      }
    ];

    services.bluemap.coreSettings.accept-download = cfg.eula;

    systemd.services."render-bluemap-maps" = lib.mkIf cfg.enableRender {
      serviceConfig = {
        Type = "oneshot";
        CPUSchedulingPolicy = "batch";
        Group = "nginx";
        UMask = "026";
        ExecStart = [
          # If web folder doesnt exist generate it
          ''|test -f "${cfg.webRoot}" || ${lib.getExe cfg.package} -c ${webappConfigFolder} -gs''
        ]
        ++
          # Render each minecraft map
          lib.attrsets.mapAttrsToList (
            name: value: "${lib.getExe cfg.package} -c ${renderConfigFolder name value} -r"
          ) cfg.maps
        ++ [
          # Generate updated webapp
          "${lib.getExe cfg.package} -c ${webappConfigFolder} -gs"
        ];
      };
    };

    systemd.timers."render-bluemap-maps" = lib.mkIf cfg.enableRender {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        Unit = "render-bluemap-maps.service";
      };
    };

    services.nginx.virtualHosts = lib.mkIf cfg.enableNginx {
      "${cfg.host}" = {
        root = config.services.bluemap.webRoot;
        locations = {
          "~* ^/maps/[^/]*/tiles/".extraConfig = ''
            error_page 404 = @empty;
          '';
          "@empty".return = "204";
        };
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [
      dandellion
      h7x4
    ];
  };
}
