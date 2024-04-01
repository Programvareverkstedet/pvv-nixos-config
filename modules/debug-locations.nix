{ config, lib, ... }:
let
  cfg = config.environment.debug-locations;
in
{
  options.environment.debug-locations = lib.mkOption {
    description = "Paths and derivations to symlink in `/etc/debug`";
    type = with lib.types; attrsOf path;
    default = { };
  };

  config.environment.etc = lib.mapAttrs' (k: v: lib.nameValuePair "debug/${k}" { source = v; }) cfg;
}
