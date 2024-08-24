{ config, lib, pkgs, ... }:
let
  cfg = config.services.pvv-doorbell-bot;
in {
  sops.secrets."doorbell-bot/config-json" = {
    owner = cfg.user;
    group = cfg.group;
  };

  services.pvv-doorbell-bot = {
    enable = true;
    settings = {
      configFile = config.sops.secrets."doorbell-bot/config-json".path;
    };
  };
}
