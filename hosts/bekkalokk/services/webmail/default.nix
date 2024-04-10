{ config, values, pkgs, lib, ... }:
{
  imports = [
    ./roundcube.nix
  ];

  services.nginx.virtualHosts."webmail.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    locations."= /" = {
      return = "302 https://webmail.pvv.ntnu.no/roundcube";
    };
  };
}
