{ inputs, pkgs, lib, ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git?ref=pvvvvv";
    flags = [
      # --update-input is deprecated since nix 2.22, and removed in lix 2.90
      # https://git.lix.systems/lix-project/lix/issues/400
      "--refresh"
      "--override-input" "nixpkgs" "github:nixos/nixpkgs/nixos-unstable-small"
      "--override-input" "nixpkgs-unstable" "github:nixos/nixpkgs/nixos-unstable-small"
      "--no-write-lock-file"
    ];
  };

  # workaround for https://github.com/NixOS/nix/issues/6895
  # via https://git.lix.systems/lix-project/lix/issues/400
  environment.etc."current-system-flake-inputs.json".source
    = pkgs.writers.writeJSON "flake-inputs.json" (
      lib.flip lib.mapAttrs inputs (name: input:
        # inputs.*.sourceInfo sans outPath, since writeJSON will otherwise serialize sourceInfo like a derivation
        lib.removeAttrs (input.sourceInfo or {}) [ "outPath" ]
          // { store-path = input.outPath; } # comment this line if you don't want to retain a store reference to the flake inputs
      )
    );
}
