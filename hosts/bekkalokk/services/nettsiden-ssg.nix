{ config, ... }:
let
  cfg = config.services.nettsiden-ssg;
in {
  services.nettsiden-ssg = {
    enable = true;
  };

  services.nginx.virtualHosts."beta.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    root = cfg.outputDir;
    locations."/" = {
      tryFiles = "$uri $uri/ =404";
    };
  };
}
