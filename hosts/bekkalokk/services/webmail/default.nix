{
  config,
  values,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./roundcube.nix
    ./snappymail.nix
  ];

  services.nginx.virtualHosts."webmail.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    locations = {
      "= /".return = "302 https://webmail.pvv.ntnu.no/roundcube";

      "/afterlogic_lite".return = "302 https://webmail.pvv.ntnu.no/roundcube";
      "/squirrelmail".return = "302 https://webmail.pvv.ntnu.no/roundcube";
      "/rainloop".return = "302 https://snappymail.pvv.ntnu.no/";
      "/snappymail".return = "302 https://snappymail.pvv.ntnu.no/";
    };
  };
}
