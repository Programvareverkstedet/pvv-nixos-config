{ lib, config, inputs, ... }:
{
  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 2d";
    };
    optimise.automatic = true;

    settings = {
      allow-dirty = true;
      auto-allocate-uids = true;
      builders-use-substitutes = true;
      experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
      log-lines = 50;
      use-xdg-base-directories = true;
    };

    /* This makes commandline tools like
    ** nix run nixpkgs#hello
    ** and nix-shell -p hello
    ** use the same channel the system
    ** was built with
    */
    registry = lib.mkMerge [
      {
        "nixpkgs".flake = inputs.nixpkgs;
        "nixpkgs-unstable".flake = inputs.nixpkgs-unstable;
      }
      # We avoid the reference to self in vmVariant to get a stable system .outPath for equivalence testing
      (lib.mkIf (!config.virtualisation.isVmVariant) {
        "pvv-nix".flake = inputs.self;
      })
    ];
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      "unstable=${inputs.nixpkgs-unstable}"
    ];
  };
}
