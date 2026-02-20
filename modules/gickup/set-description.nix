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
    # TODO: create .git/description files for each repo where cfg.instances.<instance>.description is set
  };
}
