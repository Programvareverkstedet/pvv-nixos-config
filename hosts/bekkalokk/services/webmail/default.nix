{ config, values, pkgs, lib, ... }:
{
  imports = [
    ./roundcube.nix
  ];

  services.nginx.virtualHosts."webmail2.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;
    #locations."/" = lib.mkForce { };
    locations."= /" = {
      return = "301 https://www.pvv.ntnu.no/mail/";
    };
  };
}
