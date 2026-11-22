{ config, lib, pkgs, ... }:
{
  imports = [
    ./fluentbit.nix
    ./rate-limiting.nix
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

  config = {
    services.nginx = {
      package = lib.mkDefault pkgs.nginxMainline;

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

      appendHttpConfig = ''
        map $https $alt_svc_h3 {
          on 'h3=":$server_port"; ma=86400';
          default "";
        }

        add_header_inherit merge;

        quic_gso on;
        quic_host_key /var/lib/nginx/quic_host_key;

        ssl_session_cache shared:tls_sessions:64m;
        ssl_conf_command NumTickets 1;
      '';
    };

    systemd.services.nginx = lib.mkIf config.services.nginx.enable {
      preStart = lib.mkBefore ''
        if [ ! -s /var/lib/nginx/quic_host_key ]; then
          (umask 077; head -c 32 /dev/urandom > /var/lib/nginx/quic_host_key.tmp)
          mv /var/lib/nginx/quic_host_key.tmp /var/lib/nginx/quic_host_key
        fi
      '';

      serviceConfig = {
        LimitNOFILE = 65536;
        # We use jit my dudes
        MemoryDenyWriteExecute = lib.mkForce false;
        # What the fuck do we use that where the defaults are not enough???
        SystemCallFilter = lib.mkForce null;

        StateDirectory = "nginx";
        StateDirectoryMode = "0700";
      };
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
        ]) config.services.nginx.defaultListenAddresses;

        locations."/".return = "444";
      };

      # The blackbox exporter on ildkule wants to probe this
      ${config.networking.fqdn}.locations."/" = lib.mkDefault {
        extraConfig = ''
          location = / {
            return 204;
          }
          return 404;
        '';
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 443 ];
    networking.firewall.allowedUDPPorts = lib.mkIf config.services.nginx.enable [ 443 ];

    services.logrotate.settings.nginx.rotate = lib.mkIf config.services.nginx.enable 5;
  };
}
