{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.gickup;
in
{
  config = lib.mkIf cfg.enable {
    # TODO: import cfg.instances from a toml file to make it easier for non-nix users
    #       to add repositories to mirror
  };
}
