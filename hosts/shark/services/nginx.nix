{ config, values, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "drift@pvv.ntnu.no";
  };

  services.nginx = {
    enable = true;

    enableReload = true;

    defaultListenAddresses = [
      values.hosts.shark.ipv4
      "[${values.hosts.shark.ipv6}]"

      "127.0.0.1"
      "127.0.0.2"
      "[::1]"
    ];

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
