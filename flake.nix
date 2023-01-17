{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11-small";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules";
  };

  outputs = { self, nixpkgs, unstable, sops-nix, ... }@inputs: 
  let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    nixosConfigurations = {
      jokum = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit unstable inputs; values = import ./values.nix; };
        modules = [
          ./hosts/jokum/configuration.nix
          sops-nix.nixosModules.sops

          inputs.matrix-next.nixosModules.synapse
        ];
      };
      ildkule = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit unstable inputs; values = import ./values.nix; };
        modules = [
          ./hosts/ildkule/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.callPackage ./shell.nix { };
    });
  };
}
