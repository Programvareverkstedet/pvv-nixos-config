{ ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git";
    flags = [
      # --update-input is deprecated since nix 2.22, and removed in lix 2.90
      # https://git.lix.systems/lix-project/lix/issues/400
      "--refresh"
      "--override-input" "nixpkgs" "github:nixos/nixpkgs/nixos-24.05-small"
      "--override-input" "nixpkgs-unstable" "github:nixos/nixpkgs/nixos-unstable-small"
      "--no-write-lock-file"
    ];
  };
}