{config, ... }:

{

  security.acme = {
    acceptTerms = true;
    defaults.email = "danio@pvv.ntnu.no";
  };

  services.nginx = {
    enable = true;

    defaultListenAddresses = [ "129.241.210.169" "127.0.0.1" "[2001:700:300:1900::169]" ];

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
