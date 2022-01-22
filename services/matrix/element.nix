{ config, lib, pkgs, ... }:

{
  services.nginx.virtualHosts."chat.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;

    root = pkgs.element-web.override {
      conf = {
        default_server_config."m.homeserver" = {
          base_url = "https://matrix.pvv.ntnu.no";
          server_name = "pvv.ntnu.no";
        };
        disable_3pid_login = true;
#        integrations_ui_url = "https://dimension.dodsorf.as/riot";
#        integrations_rest_url = "https://dimension.dodsorf.as/api/v1/scalar";
#        integrations_widgets_urls = [
#          "https://dimension.dodsorf.as/widgets"
#        ];
#        integration_jitsi_widget_url = "https://dimension.dodsorf.as/widgets/jitsi";
        defaultCountryCode = "NO";
        showLabsSettings = true;
        features = {
          feature_latex_maths = true;
          feature_pinning = true;
          feature_state_counters = true;
          feature_custom_status = false;
        };
        default_theme = "dark";
        roomDirectory.servers = [
          "pvv.ntnu.no"
          "matrix.org"
          "libera.chat"
          "gitter.im"
          "mozilla.org"
          "kde.org"
          "t2bot.io"
          "fosdem.org"
          "dodsorf.as"
        ];
        enable_presence_by_hs_url = {
          "https://matrix.org" = false;
          "https://matrix.dodsorf.as" = false;
        };
      };
    };
  };
}
