{ config, fp, ... }:
{
  imports = [ (fp /modules/grzegorz.nix) ];

  # Current hardware has Ivy Bridge GPU
  services.greg-ng.mpv.settings.default = {
    # No vulkan, cuda or other funny business
    hwdec = "vaapi";

    # Safe codecs, should work
    hwdec-codecs = "h264,mpeg2video,vc1";

    # Incomplete vulkan support in mesa
    gpu-api = "opengl";
  };

  services.nginx.virtualHosts."${config.networking.fqdn}" = {
    serverAliases = [
      "bokhylle.pvv.ntnu.no"
      "bokhylle.pvv.org"
    ];
  };
}
