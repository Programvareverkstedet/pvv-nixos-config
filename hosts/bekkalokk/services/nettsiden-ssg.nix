{ config, ... }:
let
  cfg = config.services.nettsiden-ssg;
in {
  services.nettsiden-ssg = {
    enable = true;
  };

  services.nginx.virtualHosts."beta.pvv.ntnu.no" = {
    enableACME = true;
    root = cfg.outputDir;
  };
}
