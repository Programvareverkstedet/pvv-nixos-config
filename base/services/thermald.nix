{ config, lib, ... }:
{
  # Let's not thermal throttle
  services.thermald.enable = lib.mkIf (lib.all (x: x) [
      (config.nixpkgs.system == "x86_64-linux")
      (!config.boot.isContainer or false)
    ]) true;
}