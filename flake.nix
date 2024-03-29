{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11-small";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable-small";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    pvv-calendar-bot.url = "git+https://git.pvv.ntnu.no/Projects/calendar-bot.git";
    pvv-calendar-bot.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules";
    matrix-next.inputs.nixpkgs.follows = "nixpkgs";

    grzegorz.url = "github:Programvareverkstedet/grzegorz";
    grzegorz.inputs.nixpkgs.follows = "nixpkgs-unstable";
    grzegorz-clients.url = "github:Programvareverkstedet/grzegorz-clients";
    grzegorz-clients.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, disko, ... }@inputs:
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
            overlays = [ ] ++ config.overlays or [ ];
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
            heimdal = final.callPackage ./packages/heimdal {
              inherit (final.darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
              autoreconfHook = final.buildPackages.autoreconfHook269;
	    };
          })
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
      buskerud = stableNixosConfig "buskerud" { };
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

        #######################
        # TODO: remove this once nixos 24.05 gets released
        #######################
        heimdal = pkgs.callPackage ./packages/heimdal {
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
          autoreconfHook = pkgs.buildPackages.autoreconfHook269;
	};
      } // nixlib.genAttrs allMachines
        (machine: self.nixosConfigurations.${machine}.config.system.build.toplevel);
    };
  };
}
