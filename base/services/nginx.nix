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

    appendHttpConfig = ''
      log_format vhost_combined '$host $remote_addr - $remote_user [$time_local] '
                                 '"$request" $status $body_bytes_sent '
                                 '"$http_referer" "$http_user_agent"';
      access_log /var/log/nginx/access.log vhost_combined;
      error_log /var/log/nginx/error.log;
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

  services.fluent-bit.settings.parsers = lib.mkIf (config.services.nginx.enable && config.services.fluent-bit.enable) [
    {
      name = "nginx_access";
      format = "regex";
      regex = ''^(?<vhost>[^ ]*) (?<remote>[^ ]*) - (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?) +\S*)?" (?<status>[^ ]*) (?<bytes>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$'';
      time_key = "time";
      time_format = "%d/%b/%Y:%H:%M:%S %z";
      time_keep = false;
    }
    {
      name = "nginx_error";
      format = "regex";
      regex = ''^(?<time>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<pid>\d+)#(?<tid>\d+): \*(?<cid>\d+)? (?<message>.*)$'';
      time_key = "time";
      time_format = "%Y/%m/%d %H:%M:%S";
      time_keep = false;
    }
  ];

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

    filters = [
      {
        name = "parser";
        match = "nginx.access";
        key_name = "log";
        parser = "nginx_access";
        reserve_data = true;
        preserve_key = false;
      }
      {
        name = "parser";
        match = "nginx.error";
        key_name = "log";
        parser = "nginx_error";
        reserve_data = true;
        preserve_key = false;
      }
      {
        name = "modify";
        match = "nginx.access";
        set = "level info";
      }
      {
        name = "modify";
        match = "nginx.error";
        set = "level error";
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
      label_keys = "$level";

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
