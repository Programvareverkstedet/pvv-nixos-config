{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "https://nixos.org/channels/nixos-25.11-small/nixexprs.tar.xz";
    nixpkgs-unstable.url = "https://nixos.org/channels/nixos-unstable-small/nixexprs.tar.xz";

    sops-nix.url = "github:Mic92/sops-nix/master";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko/v1.11.0";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-topology.url = "github:oddlama/nix-topology/main";
    nix-topology.inputs.nixpkgs.follows = "nixpkgs";

    pvv-nettsiden.url = "git+https://git.pvv.ntnu.no/Projects/nettsiden.git?ref=main";
    pvv-nettsiden.inputs.nixpkgs.follows = "nixpkgs";

    pvv-calendar-bot.url = "git+https://git.pvv.ntnu.no/Projects/calendar-bot.git?ref=main";
    pvv-calendar-bot.inputs.nixpkgs.follows = "nixpkgs";

    dibbler.url = "git+https://git.pvv.ntnu.no/Projects/dibbler.git?ref=main";
    dibbler.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules/v0.8.0";
    matrix-next.inputs.nixpkgs.follows = "nixpkgs";

    nix-gitea-themes.url = "git+https://git.pvv.ntnu.no/Drift/nix-gitea-themes.git?ref=main";
    nix-gitea-themes.inputs.nixpkgs.follows = "nixpkgs";

    minecraft-heatmap.url = "git+https://git.pvv.ntnu.no/Projects/minecraft-heatmap.git?ref=main";
    minecraft-heatmap.inputs.nixpkgs.follows = "nixpkgs";

    roowho2.url = "git+https://git.pvv.ntnu.no/Projects/roowho2.git?ref=main";
    roowho2.inputs.nixpkgs.follows = "nixpkgs";

    greg-ng.url = "git+https://git.pvv.ntnu.no/Grzegorz/greg-ng.git?ref=main";
    greg-ng.inputs.nixpkgs.follows = "nixpkgs";
    gergle.url = "git+https://git.pvv.ntnu.no/Grzegorz/gergle.git?ref=main";
    gergle.inputs.nixpkgs.follows = "nixpkgs";
    grzegorz-clients.url = "git+https://git.pvv.ntnu.no/Grzegorz/grzegorz-clients.git?ref=master";
    grzegorz-clients.inputs.nixpkgs.follows = "nixpkgs";

    minecraft-kartverket.url = "git+https://git.pvv.ntnu.no/Projects/minecraft-kartverket.git?ref=main";
    minecraft-kartverket.inputs.nixpkgs.follows = "nixpkgs";

    qotd.url = "git+https://git.pvv.ntnu.no/Projects/qotd.git?ref=main";
    qotd.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, disko, ... }@inputs:
  let
    inherit (nixpkgs) lib;
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = f: lib.genAttrs systems f;
    allMachines = builtins.attrNames self.nixosConfigurations;
    importantMachines = [
      "bekkalokk"
      "bicep"
      "brzeczyszczykiewicz"
      "georg"
      "ildkule"
    ];
  in {
    inputs = lib.mapAttrs (_: src: src.outPath) inputs;

    pkgs = forAllSystems (system: import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg)
        [
          "nvidia-x11"
          "nvidia-settings"
        ];
    });

    nixosConfigurations = let
      nixosConfig =
        nixpkgs:
        name:
        configurationPath:
        extraArgs@{
          localSystem ? "x86_64-linux", # buildPlatform
          crossSystem ? "x86_64-linux", # hostPlatform
          specialArgs ? { },
          modules ? [ ],
          overlays ? [ ],
          enableDefaults ? true,
          ...
        }:
        let
          commonPkgsConfig = {
            inherit localSystem crossSystem;
            config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg)
              [
                "nvidia-x11"
                "nvidia-settings"
              ];
            overlays = (lib.optionals enableDefaults [
              # Global overlays go here
              inputs.roowho2.overlays.default
            ]) ++ overlays;
          };

          pkgs = import nixpkgs commonPkgsConfig;
          unstablePkgs = import nixpkgs-unstable commonPkgsConfig;
        in
        lib.nixosSystem (lib.recursiveUpdate
        {
          system = crossSystem;

          inherit pkgs;

          specialArgs = {
            inherit inputs unstablePkgs;
            values = import ./values.nix;
            fp = path: ./${path};
          } // specialArgs;

          modules = [
            {
              networking.hostName = lib.mkDefault name;
            }
            configurationPath
          ] ++ (lib.optionals enableDefaults [
            sops-nix.nixosModules.sops
            inputs.roowho2.nixosModules.default
          ]) ++ modules;
        }
        (builtins.removeAttrs extraArgs [
          "localSystem"
          "crossSystem"
          "modules"
          "overlays"
          "specialArgs"
          "enableDefaults"
        ])
      );

      stableNixosConfig = name: extraArgs:
          nixosConfig nixpkgs name ./hosts/${name}/configuration.nix extraArgs;
    in {
      bakke = stableNixosConfig "bakke" {
        modules = [
          disko.nixosModules.disko
        ];
      };
      bicep = stableNixosConfig "bicep" {
        modules = [
          inputs.matrix-next.nixosModules.default
          inputs.pvv-calendar-bot.nixosModules.default
          inputs.minecraft-heatmap.nixosModules.default
          self.nixosModules.gickup
          self.nixosModules.matrix-ooye
        ];
        overlays = [
          inputs.pvv-calendar-bot.overlays.default
          inputs.minecraft-heatmap.overlays.default
          (final: prev: {
            inherit (self.packages.${prev.stdenv.hostPlatform.system}) out-of-your-element;
          })
        ];
      };
      bekkalokk = stableNixosConfig "bekkalokk" {
        overlays = [
          (final: prev: {
            mediawiki-extensions = final.callPackage ./packages/mediawiki-extensions { };
            simplesamlphp = final.callPackage ./packages/simplesamlphp { };
            bluemap = final.callPackage ./packages/bluemap.nix { };
          })
          inputs.pvv-nettsiden.overlays.default
          inputs.qotd.overlays.default
        ];
        modules = [
          inputs.pvv-nettsiden.nixosModules.default
          self.nixosModules.bluemap
          inputs.qotd.nixosModules.default
        ];
      };
      ildkule = stableNixosConfig "ildkule" { };
      #ildkule-unstable = unstableNixosConfig "ildkule" { };
      shark = stableNixosConfig "shark" { };
      wenche = stableNixosConfig "wenche" { };
      temmie = stableNixosConfig "temmie" { };
      gluttony = stableNixosConfig "gluttony" { };

      kommode = stableNixosConfig "kommode" {
        overlays = [
          inputs.nix-gitea-themes.overlays.default
        ];
        modules = [
          inputs.nix-gitea-themes.nixosModules.default
        ];
      };

      ustetind = stableNixosConfig "ustetind" {
        modules = [
         "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
        ];
      };

      brzeczyszczykiewicz = stableNixosConfig "brzeczyszczykiewicz" {
        modules = [
          inputs.grzegorz-clients.nixosModules.grzegorz-webui
          inputs.gergle.nixosModules.default
          inputs.greg-ng.nixosModules.default
        ];
        overlays = [
          inputs.greg-ng.overlays.default
          inputs.gergle.overlays.default
        ];
      };
      georg = stableNixosConfig "georg" {
        modules = [
          inputs.grzegorz-clients.nixosModules.grzegorz-webui
          inputs.gergle.nixosModules.default
          inputs.greg-ng.nixosModules.default
        ];
        overlays = [
          inputs.greg-ng.overlays.default
          inputs.gergle.overlays.default
        ];
      };
    }
    //
    (let
      skrottConfig = {
        modules = [
          (nixpkgs + "/nixos/modules/installer/sd-card/sd-image-aarch64.nix")
          inputs.dibbler.nixosModules.default
        ];
        overlays = [
          inputs.dibbler.overlays.default
          (final: prev: {
            # NOTE: Yeetus
            atool = prev.emptyDirectory;
            micro = prev.emptyDirectory;
          })
        ];
      };
    in {
      skrott = self.nixosConfigurations.skrott-native;
      skrott-native = stableNixosConfig "skrott" (skrottConfig // {
        localSystem = "aarch64-linux";
        crossSystem = "aarch64-linux";
      });
      skrott-cross = stableNixosConfig "skrott" (skrottConfig // {
        localSystem = "x86_64-linux";
        crossSystem = "aarch64-linux";
      });
      skrott-x86_64 = stableNixosConfig "skrott" (skrottConfig // {
        localSystem = "x86_64-linux";
        crossSystem = "x86_64-linux";
      });
    })
    //
    (let
      machineNames = map (i: "lupine-${toString i}") (lib.range 1 5);
      stableLupineNixosConfig = name: extraArgs:
          nixosConfig nixpkgs name ./hosts/lupine/configuration.nix extraArgs;
    in lib.genAttrs machineNames (name: stableLupineNixosConfig name {
      modules = [{ networking.hostName = name; }];
      specialArgs.lupineName = name;
    }));

    nixosModules = {
      bluemap = ./modules/bluemap.nix;
      snakeoil-certs = ./modules/snakeoil-certs.nix;
      snappymail = ./modules/snappymail.nix;
      robots-txt = ./modules/robots-txt.nix;
      gickup = ./modules/gickup;
      matrix-ooye = ./modules/matrix-ooye.nix;
    };

    devShells = forAllSystems (system: {
      default = nixpkgs-unstable.legacyPackages.${system}.callPackage ./shell.nix { };
      cuda = let
        cuda-pkgs = import nixpkgs-unstable {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };
      in cuda-pkgs.callPackage ./shells/cuda.nix { };
    });

    packages = {
      "x86_64-linux" = let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        default = important-machines;
        important-machines = pkgs.linkFarm "important-machines"
          (lib.getAttrs importantMachines self.packages.${system});
        all-machines = pkgs.linkFarm "all-machines"
          (lib.getAttrs allMachines self.packages.${system});

        simplesamlphp = pkgs.callPackage ./packages/simplesamlphp { };

        bluemap = pkgs.callPackage ./packages/bluemap.nix { };

        out-of-your-element = pkgs.callPackage ./packages/ooye/package.nix { };
      }
      //
      # Mediawiki extensions
      (lib.pipe null [
        (_: pkgs.callPackage ./packages/mediawiki-extensions { })
        (lib.flip builtins.removeAttrs ["override" "overrideDerivation"])
        (lib.mapAttrs' (name: lib.nameValuePair "mediawiki-${name}"))
      ])
      //
      # Machines
      lib.genAttrs allMachines
        (machine: self.nixosConfigurations.${machine}.config.system.build.toplevel)
      //
      # Skrott is exception
      {
        skrott = self.packages.${system}.skrott-native;
        skrott-native = self.nixosConfigurations.skrott-native.config.system.build.sdImage;
        skrott-cross = self.nixosConfigurations.skrott.config.system.build.sdImage;
        skrott-x86_64 = self.nixosConfigurations.skrott.config.system.build.toplevel;
      }
      //
      # Nix-topology
      (let
        topology' = import inputs.nix-topology {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              inputs.nix-topology.overlays.default
              (final: prev: {
                inherit (nixpkgs-unstable.legacyPackages.${system}) super-tiny-icons;
              })
            ];
          };

          specialArgs = {
            values = import ./values.nix;
          };

          modules = [
            ./topology
            {
              nixosConfigurations = lib.mapAttrs (_name: nixosCfg: nixosCfg.extendModules {
                modules = [
                  inputs.nix-topology.nixosModules.default
                  ./topology/service-extractors/greg-ng.nix
                  ./topology/service-extractors/postgresql.nix
                  ./topology/service-extractors/mysql.nix
                  ./topology/service-extractors/gitea-runners.nix
                ];
              }) self.nixosConfigurations;
            }
          ];
        };
      in {
        topology = topology'.config.output;
        topology-png = pkgs.runCommand "pvv-config-topology-png" {
          nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
        } ''
          mkdir -p "$out"
          for file in '${topology'.config.output}'/*.svg; do
            ${lib.getExe pkgs.imagemagick} -density 300 -background none "$file" "$out"/"$(basename "''${file%.svg}.png")"
          done
        '';
      });
    };
  };
}
