{ config, lib, pkgs, ... }:
let
  cfg = config.services.pvv-calendar-bot;
in {
  sops.secrets."calendar-bot/matrix_token" = {
    sopsFile = ../../../secrets/bicep/bicep.yaml;
    key = "calendar-bot/matrix_token";
    owner = cfg.user;
    group = cfg.group;
  };

  services.pvv-calendar-bot = {
    enable = true;

    settings = {
      matrix = {
        homeserver = "https://matrix.pvv.ntnu.no";
        user = "@bot_calendar:pvv.ntnu.no";
        channel = "!gkNLUIhYVpEyLatcRz:pvv.ntnu.no";
      };
      secretsFile = config.sops.secrets."calendar-bot/matrix_token".path;
      onCalendar = "*-*-* 09:00:00";
    };
  };
}
