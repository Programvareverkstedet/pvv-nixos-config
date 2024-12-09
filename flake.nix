{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05-small"; # remember to also update the url in base/services/auto-upgrade.nix
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    pvv-nettsiden.url = "git+https://git.pvv.ntnu.no/Projects/nettsiden.git";
    pvv-nettsiden.inputs.nixpkgs.follows = "nixpkgs";

    pvv-calendar-bot.url = "git+https://git.pvv.ntnu.no/Projects/calendar-bot.git";
    pvv-calendar-bot.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules/v0.6.1";
    matrix-next.inputs.nixpkgs.follows = "nixpkgs";

    nix-gitea-themes.url = "git+https://git.pvv.ntnu.no/oysteikt/nix-gitea-themes.git";
    nix-gitea-themes.inputs.nixpkgs.follows = "nixpkgs";

    greg-ng.url = "git+https://git.pvv.ntnu.no/Projects/greg-ng.git";
    greg-ng.inputs.nixpkgs.follows = "nixpkgs";
    grzegorz-clients.url = "git+https://git.pvv.ntnu.no/Projects/grzegorz-clients.git";
    grzegorz-clients.inputs.nixpkgs.follows = "nixpkgs";

    minecraft-data.url = "git+https://git.pvv.ntnu.no/Drift/minecraft-data.git";
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
      nixosConfig = nixpkgs: name: config: lib.nixosSystem (lib.recursiveUpdate
        rec {
          system = "x86_64-linux";
          specialArgs = {
            inherit unstablePkgs inputs;
            values = import ./values.nix;
            fp = path: ./${path};
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
            bluemap = final.callPackage ./packages/bluemap.nix { };
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

      ustetind = stableNixosConfig "ustetind" {
        modules = [
         "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
        ];
      };

      brzeczyszczykiewicz = stableNixosConfig "brzeczyszczykiewicz" {
        modules = [
          inputs.grzegorz-clients.nixosModules.grzegorz-webui
          inputs.greg-ng.nixosModules.default
        ];
        overlays = [
          inputs.greg-ng.overlays.default
        ];
      };
      georg = stableNixosConfig "georg" {
        modules = [
          inputs.grzegorz-clients.nixosModules.grzegorz-webui
          inputs.greg-ng.nixosModules.default
        ];
        overlays = [
          inputs.greg-ng.overlays.default
        ];
      };
    };

    nixosModules = {
      snakeoil-certs = ./modules/snakeoil-certs.nix;
      snappymail = ./modules/snappymail.nix;
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
          (lib.getAttrs importantMachines self.packages.x86_64-linux);
        all-machines = pkgs.linkFarm "all-machines"
          (lib.getAttrs allMachines self.packages.x86_64-linux);

        simplesamlphp = pkgs.callPackage ./packages/simplesamlphp { };

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
