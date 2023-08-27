{ config, lib, pkgs, ... }:

{
  sops.secrets."calendar-bot/matrix_token" = {
    sopsFile = ../../../secrets/bicep/bicep.yaml;
  };

  services.pvv-calendar-bot = {
    enable = true;
    settings = {
      matrix = {
        homeserver = "https://matrix.pvv.ntnu.no";
        user = "@bot_calendar:pvv.ntnu.no";
        channel = "!MCYRZwhWAeNqUhwkUx:feal.no";
      };
      secretsFile = config.sops.secrets."calendar-bot/matrix_token".path;
      onCalendar = "0 9 * * *";
    };
  };
}
