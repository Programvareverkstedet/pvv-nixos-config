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
      values.hosts.ildkule.ipv4
      "[${values.hosts.ildkule.ipv6}]"

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
