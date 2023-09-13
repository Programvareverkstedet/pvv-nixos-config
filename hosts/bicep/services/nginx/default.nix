{ config, values, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "danio@pvv.ntnu.no";
  };

  services.nginx = {
    enable = true;

    enableReload = true;

    defaultListenAddresses = [
      values.hosts.bicep.ipv4
      "[${values.hosts.bicep.ipv6}]"

      "127.0.0.1"
      "127.0.0.2"
      "[::1]"
    ];

    appendConfig = ''
      pcre_jit on;
      worker_processes 8;
      worker_rlimit_nofile 8192;
    '';

    eventsConfig = ''
      multi_accept on;
      worker_connections 4096;
    '';

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  systemd.services.nginx.serviceConfig = {
    LimitNOFILE = 65536;
  };
}
