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
      # i.e. if `$request_method` == "", it's likely just bogus bytes and we add the
      # entire request to the $log_invalid_request field in the json output.
      map $request_method $log_invalid_request {
        "" $request;
        default "";
      }

      # Only log whether or not the request had cookies, not the cookies themselves.
      map $http_cookie $log_has_cookie {
        "" "0";
        default "1";
      }

      log_format vhost_json escape=json '${builtins.toJSON {
        time = "$time_local";
        vhost = "$host";
        remote = "$remote_addr";
        user = "$remote_user";
        method = "$request_method";
        path = "$request_uri";
        protocol = "$server_protocol";
        invalid_request = "$log_invalid_request";
        status = "$status";
        bytes = "$body_bytes_sent";
        referer = "$http_referer";
        agent = "$http_user_agent";

        # Client fingerprinting
        sec_ch_ua = "$http_sec_ch_ua";
        sec_fetch_site = "$http_sec_fetch_site";
        sec_fetch_mode = "$http_sec_fetch_mode";
        sec_fetch_dest = "$http_sec_fetch_dest";
        accept_language = "$http_accept_language";
        accept_encoding = "$http_accept_encoding";
        has_cookie = "$log_has_cookie";
        connection_requests = "$connection_requests";
        ssl_protocol = "$ssl_protocol";

        # Performance and rate limiting
        request_time = "$request_time";
        upstream_response_time = "$upstream_response_time";
        limit_req_status = "$limit_req_status";
      }}';
      access_log /var/log/nginx/access.log vhost_json;
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
      format = "json";
      time_key = "time";
      time_format = "%d/%b/%Y:%H:%M:%S %z";
      time_keep = false;
    }
    {
      name = "nginx_error";
      format = "regex";
      regex = "^${lib.concatStringsSep " " [
        "(?<time>[^ ]+ [^ ]+)"
        "\\[(?<level>[^\\]]+)\\]"
      ]}${lib.concatStrings [
        "(?: (?<pid>\\d+)#(?<tid>\\d+):)?"
        "(?: \\*(?<cid>\\d+))?"
        "(?: (?<message>.*?))?"
        "(?:, client: (?<client>[^,]+))?"
        "(?:, server: (?<vhost>[^,]+))?"
        "(?:, request: \"(?<request>[^\"]*)\")?"
        "(?:, upstream: \"(?<upstream>[^\"]*)\")?"
        "(?:, host: \"(?<host>[^\"]*)\")?"
        "(?:, referrer: \"(?<referrer>[^\"]*)\")?"
      ]}$";
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
