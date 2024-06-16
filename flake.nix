{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11-small";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable-small";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    pvv-nettsiden.url = "git+https://git.pvv.ntnu.no/Projects/nettsiden.git";
    pvv-nettsiden.inputs.nixpkgs.follows = "nixpkgs";

    pvv-calendar-bot.url = "git+https://git.pvv.ntnu.no/Projects/calendar-bot.git";
    pvv-calendar-bot.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules";
    matrix-next.inputs.nixpkgs.follows = "nixpkgs";

    nix-gitea-themes.url = "git+https://git.pvv.ntnu.no/oysteikt/nix-gitea-themes.git";
    nix-gitea-themes.inputs.nixpkgs.follows = "nixpkgs";

    grzegorz.url = "github:Programvareverkstedet/grzegorz";
    grzegorz.inputs.nixpkgs.follows = "nixpkgs-unstable";
    grzegorz-clients.url = "github:Programvareverkstedet/grzegorz-clients";
    grzegorz-clients.inputs.nixpkgs.follows = "nixpkgs";

    ozai.url = "git+https://git.pvv.ntnu.no/Projects/ozai.git";
    ozai.inputs.nixpkgs.follows = "nixpkgs";
    ozai-webui.url = "git+https://git.pvv.ntnu.no/adriangl/ozai-webui.git";
    ozai-webui.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, pvv-nettsiden, sops-nix, disko, ozai, ozai-webui, ... }@inputs:
  let
    nixlib = nixpkgs.lib;
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixlib.genAttrs systems (system: f system);
    allMachines = nixlib.mapAttrsToList (name: _: name) self.nixosConfigurations;
    importantMachines = [
      "bekkalokk"
      "bicep"
      "brzeczyszczykiewicz"
      "georg"
      "ildkule"
    ];
  in {
    nixosConfigurations = let
      unstablePkgs = nixpkgs-unstable.legacyPackages.x86_64-linux;
      nixosConfig = nixpkgs: name: config: nixpkgs.lib.nixosSystem (nixpkgs.lib.recursiveUpdate
        rec {
          system = "x86_64-linux";
          specialArgs = {
            inherit nixpkgs-unstable inputs;
            values = import ./values.nix;
          };

          modules = [
            ./hosts/${name}/configuration.nix
            sops-nix.nixosModules.sops
          ] ++ config.modules or [];

          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              # Global overlays go here
            ] ++ config.overlays or [ ];
          };
        }
        (removeAttrs config [ "modules" "overlays" ])
      );

      stableNixosConfig = nixosConfig nixpkgs;
      unstableNixosConfig = nixosConfig nixpkgs-unstable;
    in {
      bicep = stableNixosConfig "bicep" {
        modules = [
          inputs.matrix-next.nixosModules.default
          inputs.pvv-calendar-bot.nixosModules.default
        ];
        overlays = [
          inputs.pvv-calendar-bot.overlays.x86_64-linux.default
        ];
      };
      bekkalokk = stableNixosConfig "bekkalokk" {
        overlays = [
          (final: prev: {
            heimdal = unstablePkgs.heimdal;
            mediawiki-extensions = final.callPackage ./packages/mediawiki-extensions { };
            simplesamlphp = final.callPackage ./packages/simplesamlphp { };
          })
          inputs.nix-gitea-themes.overlays.default
          inputs.pvv-nettsiden.overlays.default
        ];
        modules = [
          inputs.nix-gitea-themes.nixosModules.default
          inputs.pvv-nettsiden.nixosModules.default
        ];
      };
      bob = stableNixosConfig "bob" {
        modules = [
          disko.nixosModules.disko
          { disko.devices.disk.disk1.device = "/dev/vda"; }
        ];
      };
      ildkule = stableNixosConfig "ildkule" { };
      #ildkule-unstable = unstableNixosConfig "ildkule" { };
      shark = stableNixosConfig "shark" { };

      brzeczyszczykiewicz = stableNixosConfig "brzeczyszczykiewicz" {
        modules = [
          inputs.grzegorz.nixosModules.grzegorz-kiosk
          inputs.grzegorz-clients.nixosModules.grzegorz-webui
        ];
      };
      georg = stableNixosConfig "georg" {
        modules = [
          inputs.grzegorz.nixosModules.grzegorz-kiosk
          inputs.grzegorz-clients.nixosModules.grzegorz-webui
        ];
      };
      buskerud = stableNixosConfig "buskerud" {
        modules = [
          ozai.nixosModules.ozai
          ozai-webui.nixosModules.ozai-webui
        ];
      };
    };

    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.callPackage ./shell.nix { };
    });

    packages = {
      "x86_64-linux" = let
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
      in rec {
        default = important-machines;
        important-machines = pkgs.linkFarm "important-machines"
          (nixlib.getAttrs importantMachines self.packages.x86_64-linux);
        all-machines = pkgs.linkFarm "all-machines"
          (nixlib.getAttrs allMachines self.packages.x86_64-linux);

        simplesamlphp = pkgs.callPackage ./packages/simplesamlphp { };

      } //
      (nixlib.pipe null [
        (_: pkgs.callPackage ./packages/mediawiki-extensions { })
        (nixlib.flip builtins.removeAttrs ["override" "overrideDerivation"])
        (nixlib.mapAttrs' (name: nixlib.nameValuePair "mediawiki-${name}"))
      ])
      // nixlib.genAttrs allMachines
        (machine: self.nixosConfigurations.${machine}.config.system.build.toplevel);
    };
  };
}
