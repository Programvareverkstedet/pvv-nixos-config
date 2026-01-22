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
      # pcre_jit on;
      worker_processes auto;
      worker_rlimit_nofile 100000;
    '';
    eventsConfig = ''
      worker_connections 2048;
      use epoll;
      # multi_accept on;
    '';
  };

  systemd.services.nginx.serviceConfig = lib.mkIf config.services.nginx.enable {
    LimitNOFILE = 65536;
    # We use jit my dudes
    MemoryDenyWriteExecute = lib.mkForce false;
    # What the fuck do we use that where the defaults are not enough???
    SystemCallFilter = lib.mkForce null;
  };

  services.nginx.virtualHosts = lib.mkIf config.services.nginx.enable {
    "_" = {
      listen = [
        {
          addr = "0.0.0.0";
          extraParameters = [
            "default_server"
            # Seemingly the default value of net.core.somaxconn
            "backlog=4096"
            "deferred"
          ];
        }
        {
          addr = "[::0]";
          extraParameters = [
            "default_server"
            "backlog=4096"
            "deferred"
          ];
        }
      ];
      sslCertificate = "/etc/certs/nginx.crt";
      sslCertificateKey = "/etc/certs/nginx.key";
      addSSL = true;
      extraConfig = "return 444;";
    };

    ${config.networking.fqdn} = {
      sslCertificate = lib.mkDefault "/etc/certs/nginx.crt";
      sslCertificateKey = lib.mkDefault "/etc/certs/nginx.key";
      addSSL = lib.mkDefault true;
      extraConfig = lib.mkDefault "return 444;";
    };
  };
}
