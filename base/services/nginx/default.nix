{ config, lib, ... }:
{
  imports = [
    ./fluentbit.nix
  ];

  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, options, ... }: let
      mkVhostDefault = lib.mkOverride 999;
      hasCertificate = config.enableACME || config.useACMEHost != null || options.sslCertificate.isDefined;
      hasOtherSSLMode = config.addSSL || config.onlySSL || config.rejectSSL;
    in {
      config = {
        forceSSL = mkVhostDefault (hasCertificate && !hasOtherSSLMode);
        kTLS = mkVhostDefault true;
        quic = mkVhostDefault true;

        extraConfig = lib.mkIf (config.quic && config.http3 && (config.onlySSL || config.addSSL || config.forceSSL)) ''
          add_header Alt-Svc $alt_svc_h3;
        '';
      };
    }));
  };

  options.services.nginx.upstreams = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options.keepalive = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 8;
      };

      config.extraConfig = lib.mkIf (config.keepalive != null) (lib.mkAfter ''
        keepalive ${toString config.keepalive};
      '');
    }));
  };

  # https://blog.nginx.org/blog/rate-limiting-nginx
  # https://nginx.org/en/docs/http/ngx_http_limit_req_module.html
  options.services.nginx.rateLimitZones = lib.mkOption {
    default = { };
    example = {
      scrapers = {
        size = "10m";
        rate = "1r/s";
      };
    };
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        key = lib.mkOption {
          type = lib.types.str;
          default = "$binary_remote_subnet";
          example = "$cookie_SESSIONID";
          description = ''
            Key to rate limit by.

            The default keys IPv4 by address and IPv6 by its /64 prefix.
          '';
        };
        size = lib.mkOption {
          type = lib.type.str;
          default = "10m";
          description = ''
            Size of the shared memory zone.

            `1m` holds about 16_000 keys for `$binary_remote_addr`.
          '';
        };
        rate = lib.mkOption {
          type = lib.types.str;
          default = "1r/s";
          example = "30r/m";
          description = ''
            Max request rate per key.

           Specify requests per second (`r/s`) or minute (`r/m`).
          '';
        };
      };
    });
  };

  config = {
    services.nginx = {
      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      enableQuicBPF = true;

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

      appendHttpConfig = lib.mkMerge [
        ''
          # Group IPv6 clients by /64, IPv4 clients by /32.
          map $binary_remote_addr $binary_remote_subnet {
            "~(?s)^(?<prefix>.{8}).{8}$" $prefix;
            default $binary_remote_addr;
          }

          map $https $alt_svc_h3 {
            on 'h3=":$server_port"; ma=86400';
            default "";
          }

          quic_gso on;
        ''

        (lib.mkIf (config.services.nginx.rateLimitZones != { }) (lib.pipe config.services.nginx.rateLimitZones [
          (lib.mapAttrsToList (name: zone: "limit_req_zone ${zone.key} zone=${name}:${zone.size} rate=${zone.rate};"))
          lib.concatLines
          lib.mkAfter
        ]))
      ];
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
        rejectSSL = true;
        quic = true;
        reuseport = true;
        listen = lib.concatMap (addr: [
          {
            inherit addr;
            port = config.services.nginx.defaultHTTPListenPort;
            extraParameters = [
              "default_server"
              # Seemingly the default value of net.core.somaxconn
              "backlog=4096"
              "deferred"
            ];
          }
          {
            inherit addr;
            port = config.services.nginx.defaultSSLListenPort;
            ssl = true;
            extraParameters = [
              "default_server"
              "backlog=4096"
              "deferred"
            ];
          }
        ]) [ "0.0.0.0" "[::0]" ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 443 ];
    networking.firewall.allowedUDPPorts = lib.mkIf config.services.nginx.enable [ 443 ];

    services.logrotate.settings.nginx.rotate = lib.mkIf config.services.nginx.enable 5;
  };
}
