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
}
