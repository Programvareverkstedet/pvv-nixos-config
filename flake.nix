{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "https://nixos.org/channels/nixos-25.11-small/nixexprs.tar.xz";
    nixpkgs-unstable.url = "https://nixos.org/channels/nixos-unstable-small/nixexprs.tar.xz";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    pvv-nettsiden.url = "git+https://git.pvv.ntnu.no/Projects/nettsiden.git";
    pvv-nettsiden.inputs.nixpkgs.follows = "nixpkgs";

    pvv-calendar-bot.url = "git+https://git.pvv.ntnu.no/Projects/calendar-bot.git";
    pvv-calendar-bot.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules/v0.8.0";
    matrix-next.inputs.nixpkgs.follows = "nixpkgs";

    nix-gitea-themes.url = "git+https://git.pvv.ntnu.no/Drift/nix-gitea-themes.git";
    nix-gitea-themes.inputs.nixpkgs.follows = "nixpkgs";

    minecraft-heatmap.url = "git+https://git.pvv.ntnu.no/Projects/minecraft-heatmap.git";
    minecraft-heatmap.inputs.nixpkgs.follows = "nixpkgs";

    greg-ng.url = "git+https://git.pvv.ntnu.no/Grzegorz/greg-ng.git";
    greg-ng.inputs.nixpkgs.follows = "nixpkgs";
    gergle.url = "git+https://git.pvv.ntnu.no/Grzegorz/gergle.git";
    gergle.inputs.nixpkgs.follows = "nixpkgs";
    grzegorz-clients.url = "git+https://git.pvv.ntnu.no/Grzegorz/grzegorz-clients.git";
    grzegorz-clients.inputs.nixpkgs.follows = "nixpkgs";

    minecraft-kartverket.url = "git+https://git.pvv.ntnu.no/Projects/minecraft-kartverket.git";
    minecraft-kartverket.inputs.nixpkgs.follows = "nixpkgs";
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

    nixosConfigurations = let
      unstablePkgs = nixpkgs-unstable.legacyPackages.x86_64-linux;

      nixosConfig =
        nixpkgs:
        name:
        configurationPath:
        extraArgs:
        lib.nixosSystem (lib.recursiveUpdate
        (let
          system = "x86_64-linux";
        in {
          inherit system;

          specialArgs = {
            inherit unstablePkgs inputs;
            values = import ./values.nix;
            fp = path: ./${path};
          } // extraArgs.specialArgs or { };

          modules = [
            configurationPath
            sops-nix.nixosModules.sops
          ] ++ extraArgs.modules or [];

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg)
              [
                "nvidia-x11"
                "nvidia-settings"
              ];
            overlays = [
              # Global overlays go here
            ] ++ extraArgs.overlays or [ ];
          };
        })
        (builtins.removeAttrs extraArgs [
          "modules"
          "overlays"
          "specialArgs"
        ])
      );

      stableNixosConfig = name: extraArgs:
          nixosConfig nixpkgs name ./hosts/${name}/configuration.nix extraArgs;
    in {
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
            inherit (self.packages.${prev.system}) out-of-your-element;
          })
        ];
      };
      bekkalokk = stableNixosConfig "bekkalokk" {
        overlays = [
          (final: prev: {
            heimdal = unstablePkgs.heimdal;
            mediawiki-extensions = final.callPackage ./packages/mediawiki-extensions { };
            simplesamlphp = final.callPackage ./packages/simplesamlphp { };
            bluemap = final.callPackage ./packages/bluemap.nix { };
          })
          inputs.pvv-nettsiden.overlays.default
        ];
        modules = [
          inputs.pvv-nettsiden.nixosModules.default
        ];
      };
      ildkule = stableNixosConfig "ildkule" { };
      #ildkule-unstable = unstableNixosConfig "ildkule" { };
      shark = stableNixosConfig "shark" { };
      wenche = stableNixosConfig "wenche" { };

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
      machineNames = map (i: "lupine-${toString i}") (lib.range 1 5);
      stableLupineNixosConfig = name: extraArgs:
          nixosConfig nixpkgs name ./hosts/lupine/configuration.nix extraArgs;
    in lib.genAttrs machineNames (name: stableLupineNixosConfig name {
      modules = [{ networking.hostName = name; }];
      specialArgs.lupineName = name;
    }));

    nixosModules = {
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
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
      in rec {
        default = important-machines;
        important-machines = pkgs.linkFarm "important-machines"
          (lib.getAttrs importantMachines self.packages.x86_64-linux);
        all-machines = pkgs.linkFarm "all-machines"
          (lib.getAttrs allMachines self.packages.x86_64-linux);

        simplesamlphp = pkgs.callPackage ./packages/simplesamlphp { };

        out-of-your-element = pkgs.callPackage ./packages/out-of-your-element.nix { };
      } //
      (lib.pipe null [
        (_: pkgs.callPackage ./packages/mediawiki-extensions { })
        (lib.flip builtins.removeAttrs ["override" "overrideDerivation"])
        (lib.mapAttrs' (name: lib.nameValuePair "mediawiki-${name}"))
      ])
      // lib.genAttrs allMachines
        (machine: self.nixosConfigurations.${machine}.config.system.build.toplevel);
    };
  };
}
