{config, ... }:

{

  security.acme = {
    acceptTerms = true;
    defaults.email = "danio@pvv.ntnu.no";
  };

  services.nginx = {
    enable = true;

    defaultListenAddresses = [ "129.241.210.187" "127.0.0.1" "127.0.0.2" "[2001:700:300:1900::187]" "[::1]" ];

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
