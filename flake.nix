{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11-small";
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
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    nixosConfigurations = let
      nixosConfig = name: config: nixpkgs.lib.nixosSystem (nixpkgs.lib.recursiveUpdate
        config
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
        });

    in {
      bicep = nixosConfig "bicep" {
        modules = [ matrix-next.nixosModules.synapse ];
      };
      bekkalokk = nixosConfig "bekkalokk" { };
      greddost = nixosConfig "greddost" { };
      ildkule = nixosConfig "ildkule" { };
    };

    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.callPackage ./shell.nix { };
    });
  };
}
