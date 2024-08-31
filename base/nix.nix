{ inputs, ... }:
{
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 2d";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  /* This makes commandline tools like
  ** nix run nixpkgs#hello
  ** and nix-shell -p hello
  ** use the same channel the system
  ** was built with
  */
  nix.registry = {
    nixpkgs.flake = inputs.nixpkgs;
  };
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
}