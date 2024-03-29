{ pkgs, config, ... }:
{
  imports = [
    ./ingress.nix
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "drift@pvv.ntnu.no";
  };

  services.nginx = {
    enable = true;

    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."bekkalokk.pvv.ntnu.no" = {
      enableACME = true;
      forceSSL = true;
      locations."/".return = "301 $scheme://git.pvv.ntnu.no$request_uri";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
