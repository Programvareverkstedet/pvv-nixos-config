{ config, fp, ... }:
{
  imports = [ (fp /modules/grzegorz.nix) ];

  services.nginx.virtualHosts."${config.networking.fqdn}" = {
    serverAliases = [
      "bokhylle.pvv.ntnu.no"
      "bokhylle.pvv.org"
    ];
  };
}
