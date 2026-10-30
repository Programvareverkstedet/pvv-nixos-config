{ fp, ... }:
{
  imports = [ (fp /modules/grzegorz.nix) ];

  # Current hardware has Radeon HD 6450 GPU
  services.greg-ng.mpv.settings.default = {
    # No vulkan, cuda or other funny business
    hwdec = "vaapi";

    # Safe codecs, should work
    hwdec-codecs = "h264,mpeg2video,vc1";

    # No vulkan :(
    gpu-api = "opengl";
  };
}
