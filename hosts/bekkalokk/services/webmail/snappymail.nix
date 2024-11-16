{ config, lib, fp, pkgs, ... }:
let
  cfg = config.services.snappymail;
in {
  imports = [ (fp /modules/snappymail.nix) ];

  services.snappymail = {
    enable = true;
    hostname = "snappymail.pvv.ntnu.no";
  };

  services.nginx.virtualHosts.${cfg.hostname} = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
  };
}

