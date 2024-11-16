{ config, fp, lib, pkgs, ... }:
let
  cfg = config.services.pvv-calendar-bot;
in {
  sops.secrets = {
    "calendar-bot/matrix_token" = {
      sopsFile = fp /secrets/bicep/bicep.yaml;
      key = "calendar-bot/matrix_token";
      owner = cfg.user;
      group = cfg.group;
    };
    "calendar-bot/mysql_password" = {
      sopsFile = fp /secrets/bicep/bicep.yaml;
      key = "calendar-bot/mysql_password";
      owner = cfg.user;
      group = cfg.group;
    };
  };

  services.pvv-calendar-bot = {
    enable = true;

    settings = {
      matrix = {
        homeserver = "https://matrix.pvv.ntnu.no";
        user = "@bot_calendar:pvv.ntnu.no";
        channel = "!gkNLUIhYVpEyLatcRz:pvv.ntnu.no";
      };
      database = {
        host = "mysql.pvv.ntnu.no";
        user = "calendar-bot";
        passwordFile = config.sops.secrets."calendar-bot/mysql_password".path;
      };
      secretsFile = config.sops.secrets."calendar-bot/matrix_token".path;
      onCalendar = "*-*-* 09:00:00";
    };
  };
}
