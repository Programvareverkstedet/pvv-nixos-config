{config, ... }:

{

  security.acme.acceptTerms = true;
  security.acme.email = "danio@pvv.ntnu.no";

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
