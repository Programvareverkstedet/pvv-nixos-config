{
  description = "PVV System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11-small";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    matrix-next.url = "github:dali99/nixos-matrix-modules/flake-experiments";
  };

  outputs = { self, nixpkgs, unstable, sops-nix, ... }@inputs: {
    nixosConfigurations = {
      jokum = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit unstable; };
        modules = [
          ./hosts/jokum/configuration.nix
          sops-nix.nixosModules.sops

          inputs.matrix-next.nixosModules.synapse
        ];
      };
    };
  };
}
