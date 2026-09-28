{ config, lib, values, ... }:
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
      regex = ''^(?<time>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<pid>\d+)#(?<tid>\d+): \*(?<cid>\d+)? (?<message>.*?)(?:, client: [^,]+)?(?:, server: (?<vhost>[^,]+))?(?:,.*)?$'';
      time_key = "time";
      time_format = "%Y/%m/%d %H:%M:%S";
      time_keep = false;
      time_system_timezone = true;
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

      # Drop a variety of errors we can't turn off in nginx, which mostly originate
      # from bots and scanner dumping garbage bytes at our doorstep.
      {
        name = "grep";
        match = "nginx.error";
        exclude = let
          ignoredSslErrorCodes = [
            "0A0000C6" # SSL routines::packet length too long
            "0A00010B" # SSL routines::wrong version number
            "0A000119" # SSL routines::decryption failed or bad record mac
            "0A000136" # SSL routines::missing psk kex modes extension
          ];
        in ''message ^SSL_\w+\(\) failed \(SSL: error:(${lib.concatStringsSep "|" ignoredSslErrorCodes}):'';
      }
      {
        name = "grep";
        match = "nginx.error";
        exclude = ''message ^SSL_write\(\) failed while processing HTTP/2 connection$'';
      }
      {
        name = "grep";
        match = "nginx.error";
        exclude = ''message ^recv\(\) failed \(\d+: Input/output error\) while (processing HTTP/2 connection|sending to client)$'';
      }

      # Drop monitoring/scraping noise from the access log.
      {
        name = "grep";
        match = "nginx.access";
        logical_op = "and";
        exclude = [
          ''path ^/loki/api/v1/push''
          ''agent ^Fluent-Bit''
        ];
      }
      {
        name = "grep";
        match = "nginx.access";
        logical_op = "and";
        exclude = let
          ildkuleAddrRegex = "^(${lib.concatMapStringsSep "|" lib.escapeRegex [
            values.hosts.ildkule.ipv4
            values.hosts.ildkule.ipv6
            "127.0.0.1"
            "::1"
          ]})$";
        in [
          "remote ${ildkuleAddrRegex}"
          ''agent ^(Prometheus|Gatus)/''
        ];
      }

      {
        name = "modify";
        match = "nginx.access";
        set = [
          "level info"
          "job nginx-access"
        ];
      }
      {
        name = "modify";
        match = "nginx.access";
        condition = "Key_value_matches status ^1";
        set = "level notice";
      }
      {
        name = "modify";
        match = "nginx.access";
        condition = "Key_value_matches status ^3";
        set = "level notice";
      }
      {
        name = "modify";
        match = "nginx.access";
        condition = "Key_value_matches status ^4";
        set = "level warning";
      }
      {
        name = "modify";
        match = "nginx.access";
        condition = "Key_value_matches status ^5";
        set = "level error";
      }
      {
        name = "modify";
        match = "nginx.error";
        set = [
          "level error"
          "job nginx-error"
        ];
      }
    ];

    outputs = [{
      name = "loki";
      match = "nginx.*";

      # Drop when v5.1.2 comes out
      # https://github.com/fluent/fluent-bit/pull/12351
      workers = 1;

      host = "loki.pvv.ntnu.no";
      port = 443;
      tls = "on";
      "tls.verify" = "on";
      uri = "/loki/api/v1/push";
      compress = "gzip";

      labels = lib.concatStringsSep ", " [
        "host=${config.networking.hostName}"
        "service_name=nginx"
      ];
      label_keys = lib.concatMapStringsSep "," (k: "$" + k) [
        "level"
        "job"
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
