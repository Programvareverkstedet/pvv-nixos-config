{ pkgs, lib, ... }:
let
  modulesToBan = [
    # copy.fail
    "af_alg"
    "algif_aead"
    "algif_hash"
    "algif_rng"
    "algif_skcipher"

    # dirtyfrag / Fragnesia
    "esp4"
    "esp6"
    "rxrpc"

    # PinTheft
    "rds"
  ];
in
{
  boot.blacklistedKernelModules = modulesToBan;

  boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (mod: "install ${mod} ${lib.getExe' pkgs.coreutils "false"}") modulesToBan;

  nixpkgs.overlays = [
    (final: prev: {
      matrix-synapse-unwrapped = prev.matrix-synapse-unwrapped.overrideAttrs (old: rec {
        version = "1.157.2";
        src = final.fetchFromGitHub {
          owner = "element-hq";
          repo = "synapse";
          rev = "v${version}";
          hash = "sha256-TUHcNAXrV43+J7jqfstlYdrZrwL5kDCh03yxO+vL/gw=";
        };
      });
    })
  ];
}
