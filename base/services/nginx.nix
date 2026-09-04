{ config, lib, ... }:
{
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
    };
  };

  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 443 ];

  services.logrotate.settings.nginx.rotate = lib.mkIf config.services.nginx.enable 5;

  services.fluent-bit.settings.pipeline = lib.mkIf (config.services.nginx.enable && config.services.fluent-bit.enable) {
    inputs = [
      {
        name = "tail";
        tag = "nginx.access";
        path = "/var/log/nginx/access.log";
        db = "/var/lib/fluent-bit/nginx-access.db";
        "storage.type" = "filesystem";
      }
      {
        name = "tail";
        tag = "nginx.error";
        path = "/var/log/nginx/error.log";
        db = "/var/lib/fluent-bit/nginx-error.db";
        "storage.type" = "filesystem";
      }
    ];

    outputs = [{
      name = "loki";
      match = "nginx.*";

      host = "loki.pvv.ntnu.no";
      port = 443;
      tls = "on";
      "tls.verify" = "on";
      uri = "/loki/api/v1/push";
      compress = "gzip";

      labels = lib.concatStringsSep ", " [
        "job=nginx"
        "host=${config.networking.hostName}"
      ];

      "storage.total_limit_size" = "256M";
    }];
  };

  systemd.services.fluent-bit.serviceConfig =
    lib.mkIf (config.services.nginx.enable && config.services.fluent-bit.enable)
      {
        SupplementaryGroups = [ "nginx" ];
        BindReadOnlyPaths = [ "/var/log/nginx" ];
      };
}
