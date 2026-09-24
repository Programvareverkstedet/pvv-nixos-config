{ config, lib, values, ... }:
let
  cfg = config.services.fluent-bit;
in
{
  services.fluent-bit = {
    enable = lib.mkDefault true;
    settings = {
      service = {
        flush = 1;
        log_level = "warn";

        http_server = "on";
        http_listen = "127.0.0.1";
        http_port = 28183;

        # filesystem-backed buffering so logs survives potential outages.
        "storage.path" = "/var/lib/fluent-bit/storage";
        "storage.sync" = "normal";
        "storage.max_chunks_up" = 64;
        "storage.backlog.mem_limit" = "16M";
      };

      pipeline = {
        inputs = [{
          name = "systemd";
          tag = "journal.*";

          db = "/var/lib/fluent-bit/journal.db";
          read_from_tail = true;
          strip_underscores = true;
          lowercase = true;
          max_entries = 1000;
          "storage.type" = "filesystem";
        }];

        filters = [{
          name = "modify";
          match = "journal.*";
          rename = [
            "hostname host"
            "priority level"
            "systemd_unit unit"
          ];
        }] ++ (lib.mapAttrsToList (k: v: {
          name = "modify";
          match = "journal.*";
          condition = "Key_value_equals level ${k}";
          set = "level ${v}";
        }) {
          "7" = "debug";
          "6" = "info";
          "5" = "notice";
          "4" = "warning";
          "3" = "error";
          "2" = "crit";
          "1" = "alert";
          "0" = "emergency";
        }) ++ [
          # Drop the unit type suffix, e.g. `sshd.service` -> `sshd`
          {
            name = "lua";
            match = "journal.*";
            call = "strip_unit_suffix";
            code = ''
              function strip_unit_suffix(tag, timestamp, record)
                  if record["unit"] ~= nil then
                      record["unit"] = string.gsub(record["unit"], "%.%a+$", "")
                  end
                  return 1, timestamp, record
              end
            '';
          }

          # Remove noise
          {
            name = "modify";
            match = "journal.*";
            remove = [
              "runtime_scope"
              "source_boottime_timestamp"
              "source_monotonic_timestamp"
              "source_realtime_timestamp"
              "stream_id"
              "syslog_facility"
              "syslog_pid"
              "syslog_raw"
              "syslog_timestamp"
              "systemd_cgroup"
              "systemd_owner_uid"
              "systemd_slice"
              "transport"
            ];
          }
        ];

        outputs = [{
          name = "loki";
          match = "journal.*";

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
            "job=systemd-journal"
          ];
          label_keys = lib.concatMapStringsSep "," (k: "$" + k) [
            "host"
            "syslog_identifier"
            "level"
          ];

          structured_metadata_map_keys = lib.concatMapStringsSep "," (k: "$" + k) [
            "audit_loginuid"
            "audit_session"
            "boot_id"
            "cap_effective"
            "cmdline"
            "comm"
            "exe"
            "gid"
            "machine_id"
            "pid"
            "selinux_context"
            "systemd_invocation_id"
            "uid"
            "unit"
          ];

          # JSON is probably fine for now, then we just extract the keys we want with the grafana web ui
          # line_format = "key_value";
          # drop_single_key = true;

          "storage.total_limit_size" = "256M";
        }];
      };
    };
  };

  services.nginx = lib.mkIf cfg.enable {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-fluent-bit-exporter/metrics" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.service.http_port}/api/v2/metrics/prometheus";
        recommendedProxySettings = true;

        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      };
    };
  };

  systemd.services.fluent-bit = lib.mkIf cfg.enable {
    after = lib.mkForce [ "network-online.target" ];
    requires = lib.mkForce [ "network-online.target" ];

    serviceConfig = {
      Slice = "system-monitoring.slice";
      StateDirectory = "fluent-bit";

      # NOTE: This hardening might be way too strong for general purpose use, don't upstream this.
      AmbientCapabilities = [ "" ];
      CapabilityBoundingSet = [ "" ];
      DeviceAllow = [ "" ];
      LockPersonality = true;
      # Lua JIT, maybe other things
      MemoryDenyWriteExecute = false;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
      UMask = "0077";

      BindReadOnlyPaths = [
        "/run/systemd/journal"
      ];
    };
  };
}
