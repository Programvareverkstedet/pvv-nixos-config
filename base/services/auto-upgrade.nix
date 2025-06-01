{ config, inputs, pkgs, lib, ... }:

let
  inputUrls = lib.mapAttrs (input: value: value.url) (import "${inputs.self}/flake.nix").inputs;
in

{
  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git";
    flags = [
      "--refresh"
      "--no-write-lock-file"
      # --update-input is deprecated since nix 2.22, and removed in lix 2.90
      # as such we instead use --override-input combined with --refresh
      # https://git.lix.systems/lix-project/lix/issues/400
    ] ++ (lib.pipe inputUrls [
      (lib.intersectAttrs {
        nixpkgs = { };
        nixpkgs-unstable = { };
      })
      (lib.mapAttrsToList (input: url: ["--override-input" input url]))
      lib.concatLists
    ]);
  };

  # workaround for https://github.com/NixOS/nix/issues/6895
  # via https://git.lix.systems/lix-project/lix/issues/400
  environment.etc = lib.mkIf (!config.virtualisation.isVmVariant) {
    "current-system-flake-inputs.json".source
      = pkgs.writers.writeJSON "flake-inputs.json" (
        lib.flip lib.mapAttrs inputs (name: input:
          # inputs.*.sourceInfo sans outPath, since writeJSON will otherwise serialize sourceInfo like a derivation
          lib.removeAttrs (input.sourceInfo or {}) [ "outPath" ]
            // { store-path = input.outPath; } # comment this line if you don't want to retain a store reference to the flake inputs
        )
      );
  };
}
