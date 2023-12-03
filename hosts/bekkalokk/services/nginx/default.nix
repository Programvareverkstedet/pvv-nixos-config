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
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
