{ config, lib, values, ... }:
let
  cfg = config.services.httpd;
  fbCfg = config.services.fluent-bit;
in {
  services.fluent-bit.settings.parsers = lib.mkIf (cfg.enable && fbCfg.enable) [
    {
      name = "apache_access";
      format = "regex";
      regex = ''^(?<remote>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?) +\S*)?" (?<status>[^ ]*) (?<bytes>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$'';
      time_key = "time";
      time_format = "%d/%b/%Y:%H:%M:%S %z";
      time_keep = false;
    }
    {
      name = "apache_error";
      format = "regex";
      regex = ''^\[(?<time>[^\]]+)\] \[(?<module>[^:\]]+):(?<level>[^\]]+)\] \[pid (?<pid>\d+)(?::tid (?<tid>\d+))?\](?: \[client (?<client>[^\]]+)\])? (?<message>.*)$'';
    }
    {
      name = "userweb_path";
      format = "regex";
      regex = ''^/~(?<userweb_user>[^/]+)/.*$'';
    }
  ];

  services.fluent-bit.settings.pipeline = lib.mkIf (cfg.enable && fbCfg.enable) {
    inputs = [
      {
        name = "tail";
        tag = "httpd.access";
        path = "${cfg.logDir}/access.log";
        db = "/var/lib/fluent-bit/httpd-access.db";
        "storage.type" = "filesystem";
      }
      {
        name = "tail";
        tag = "httpd.error";
        path = "${cfg.logDir}/error.log";
        db = "/var/lib/fluent-bit/httpd-error.db";
        "storage.type" = "filesystem";
      }
      {
        name = "tail";
        tag = "httpd.cgi";
        path = "${cfg.logDir}/cgi.log";
        db = "/var/lib/fluent-bit/httpd-cgi.db";
        "storage.type" = "filesystem";
      }
    ];

    filters = [
      {
        name = "parser";
        match = "httpd.access";
        key_name = "log";
        parser = "apache_access";
        reserve_data = true;
        preserve_key = false;
      }
      {
        name = "parser";
        match = "httpd.error";
        key_name = "log";
        parser = "apache_error";
        reserve_data = true;
        preserve_key = false;
      }
      {
        name = "parser";
        match = "httpd.access";
        key_name = "path";
        parser = "userweb_path";
        reserve_data = true;
        preserve_key = true;
      }

      # Drop monitoring/scraping noise from the access log.
      {
        name = "grep";
        match = "httpd.access";
        logical_op = "and";
        exclude = [
          ''path ^/loki/api/v1/push''
          ''agent ^Fluent-Bit''
        ];
      }
      (let
        ildkuleAddrRegex = "^(${lib.concatMapStringsSep "|" lib.escapeRegex [
          values.hosts.ildkule.ipv4
          values.hosts.ildkule.ipv6
          "127.0.0.1"
          "::1"
        ]})$";
      in {
        name = "grep";
        match = "httpd.access";
        logical_op = "and";
        exclude = [
          "remote ${ildkuleAddrRegex}"
          ''agent ^(Prometheus|Gatus)/''
        ];
      })

      {
        name = "modify";
        match = "httpd.access";
        set = [
          "level info"
          "job httpd-access"
        ];
        rename = [ "userweb_user userweb-user" ];
      }
      {
        name = "modify";
        match = "httpd.error";
        set = [
          "job httpd-error"
        ];
      }
      {
        name = "modify";
        match = "httpd.cgi";
        set = [
          "level debug"
          "job httpd-cgi"
        ];
      }
    ];

    outputs = [{
      name = "loki";
      match = "httpd.*";

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
        "service_name=httpd"
      ];
      label_keys = lib.concatMapStringsSep "," (k: "$" + k) [
        "level"
        "job"
      ];

      "storage.total_limit_size" = "256M";
    }];
  };

  systemd.services.fluent-bit.serviceConfig = lib.mkIf (cfg.enable && fbCfg.enable) {
    SupplementaryGroups = [ "wwwrun" ];
    BindReadOnlyPaths = [ cfg.logDir ];
  };
}
