{ inputs, ... }:
{
  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 2d";
    };

    settings = {
      allow-dirty = true;
      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = [ "nix-command" "flakes" ];
      log-lines = 50;
      use-xdg-base-directories = true;
    };

    /* This makes commandline tools like
    ** nix run nixpkgs#hello
    ** and nix-shell -p hello
    ** use the same channel the system
    ** was built with
    */
    registry = {
      "nixpkgs".flake = inputs.nixpkgs;
      "pvv-nix".flake = inputs.self;
    };
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}