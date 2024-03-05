{ config, lib, pkgs, ... }:
let
  synapse-cfg = config.services.matrix-synapse-next;
in {
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
          feature_render_reaction_images = true;
          feature_state_counters = true;
          # element call group calls
          feature_group_calls = true;
        };
        default_theme = "dark";
        # Servers in this list should provide some sort of valuable scoping
        # matrix.org is not useful compared to matrixrooms.info,
        # because it has so many general members, rooms of all topics are on it.
        # Something matrixrooms.info is already providing.
        room_directory.servers = [
          "pvv.ntnu.no"
          "matrixrooms.info" # Searches all public room directories
          "matrix.omegav.no" # Friends
          "gitter.im" # gitter rooms
          "mozilla.org" # mozilla and friends
          "kde.org" # KDE rooms
          "fosdem.org" # FOSDEM
          "dodsorf.as" # PVV Member
          "nani.wtf" # PVV Member
        ];
        enable_presence_by_hs_url = {
          "https://matrix.org" = false;
          # "https://matrix.dodsorf.as" = false;
          "${synapse-cfg.settings.public_baseurl}" = synapse-cfg.settings.presence.enabled;
        };
      };
    };
  };
}
