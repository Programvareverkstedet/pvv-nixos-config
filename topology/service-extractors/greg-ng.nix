{ config, lib, ... }:
let
  cfg = config.services.greg-ng or { enable = false; };
in
{
  config.topology.self.services.greg-ng = lib.mkIf cfg.enable {
    name = "Greg-ng";
    icon = ../icons/greg-ng.png;
    details.listen = { text = "${cfg.settings.host}:${toString cfg.settings.port}"; };
  };
}
