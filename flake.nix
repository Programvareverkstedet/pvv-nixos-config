{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05-small";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules";
  };

  outputs = { self, nixpkgs, matrix-next, unstable, sops-nix, ... }@inputs:
  let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    nixosConfigurations = let
      nixosConfig = nixpkgs: name: config: nixpkgs.lib.nixosSystem (nixpkgs.lib.recursiveUpdate
        rec {
          system = "x86_64-linux";
          specialArgs = {
            inherit unstable inputs;
            values = import ./values.nix;
          };

          modules = [
            ./hosts/${name}/configuration.nix
            sops-nix.nixosModules.sops
          ];

          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                mx-puppet-discord = prev.mx-puppet-discord.override { nodejs_14 = final.nodejs_18; };
              })
            ];
          };
        }
        config
      );

      stableNixosConfig = nixosConfig nixpkgs;
      unstableNixosConfig = nixosConfig unstable;
    in {
      bicep = stableNixosConfig "bicep" {
        modules = [
          ./hosts/bicep/configuration.nix
          sops-nix.nixosModules.sops

          matrix-next.nixosModules.synapse
        ];
      };
      bekkalokk = stableNixosConfig "bekkalokk" { };
      greddost = stableNixosConfig "greddost" { };
      ildkule = stableNixosConfig "ildkule" { };
      ildkule-unstable = unstableNixosConfig "ildkule" { };
      jokum = stableNixosConfig "jokum" {
        modules = [ matrix-next.nixosModules.synapse ];
      };
    };

    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.callPackage ./shell.nix { };
    });
  };
}
