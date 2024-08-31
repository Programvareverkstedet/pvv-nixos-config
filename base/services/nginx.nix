{ config, lib, ... }:
{
  # nginx return 444 for all nonexistent virtualhosts

  systemd.services.nginx.after = [ "generate-snakeoil-certs.service" ];

  environment.snakeoil-certs = lib.mkIf config.services.nginx.enable {
    "/etc/certs/nginx" = {
      owner = "nginx";
      group = "nginx";
    };
  };

  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 443 ];

  services.nginx = {
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    appendConfig = ''
      pcre_jit on;
      worker_processes auto;
      worker_rlimit_nofile 100000;
    '';
    eventsConfig = ''
      worker_connections 2048;
      use epoll;
      multi_accept on;
    '';
  };

  systemd.services.nginx.serviceConfig = lib.mkIf config.services.nginx.enable {
    LimitNOFILE = 65536;
  };

  services.nginx.virtualHosts."_" = lib.mkIf config.services.nginx.enable {
    sslCertificate = "/etc/certs/nginx.crt";
    sslCertificateKey = "/etc/certs/nginx.key";
    addSSL = true;
    extraConfig = "return 444;";
  };
}