{ config, lib, fp, values, ... }:
let
  matrixDomain = "matrix.pvv.ntnu.no";
  cfg = config.services.livekit;
in
{
  sops.secrets."matrix/livekit/keyfile/pvv" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "livekit/keyfile/pvv";
  };
  sops.secrets."matrix/livekit/keyfile/dodsorfas" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "livekit/keyfile/dodsorfas";
  };
  sops.templates."matrix-livekit-keyfile" = {
    restartUnits = [ "livekit.service" ];
    content = ''
      pvv: ${config.sops.placeholder."matrix/livekit/keyfile/pvv"}
      dodsorfas: ${config.sops.placeholder."matrix/livekit/keyfile/dodsorfas"}
    '';
  };
  sops.templates."matrix-lk-jwt-keyfile" = {
    restartUnits = [ "lk-jwt-service.service" ];
    content = ''
      pvv: ${config.sops.placeholder."matrix/livekit/keyfile/pvv"}
    '';
  };

  services.pvv-matrix-well-known.client = lib.mkIf cfg.enable {
    "org.matrix.msc4143.rtc_foci" = [{
      type = "livekit";
      livekit_service_url = "https://${matrixDomain}/livekit/jwt";
    }];
  };

  services.livekit = {
    enable = true;
    openFirewall = true;
    keyFile = config.sops.templates."matrix-livekit-keyfile".path;

    # NOTE: needed for ingress/egress workers
    # redis.createLocally = true;

    settings = {
      # room.auto_create = false;
      rtc.use_external_ip = true;
      prometheus_port = 6789;

      # NOTE: will land in 26.11
      # webhook = {
      #   api_key = "lk-jwt-service";
      #   urls = [ "https://${matrixDomain}/livekit/jwt/sfu_webhook" ];
      # };
    };
  };

  services.lk-jwt-service = lib.mkIf cfg.enable {
    enable = true;
    livekitUrl = "wss://${matrixDomain}/livekit/sfu";
    keyFile = config.sops.templates."matrix-lk-jwt-keyfile".path;
  };

  systemd.services.lk-jwt-service = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];

    environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = builtins.concatStringsSep "," [ "pvv.ntnu.no" ];
  };

  services.nginx.upstreams = lib.mkIf cfg.enable {
    lk-jwt-service.servers."127.0.0.1:${toString config.services.lk-jwt-service.port}" = { };
    livekit.servers."127.0.0.1:${toString config.services.livekit.settings.port}" = { };
    livekit-metrics.servers."127.0.0.1:${toString cfg.settings.prometheus_port}" = { };
  };

  services.nginx.virtualHosts.${matrixDomain} = lib.mkIf cfg.enable {
    locations."^~ /livekit/jwt/" = {
      proxyPass = "http://lk-jwt-service/";
    };

    # TODO: load balance to multiple livekit ingress/egress workers
    locations."^~ /livekit/sfu/" = {
      proxyPass = "http://livekit/";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_send_timeout 120;
        proxy_read_timeout 120;
        proxy_buffering off;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };

    locations."/prometheus-livekit/metrics" = {
      proxyPass = "http://livekit-metrics/metrics";
      extraConfig = ''
        allow 127.0.0.1;
        allow ::1;
        allow ${values.hosts.ildkule.ipv4};
        allow ${values.hosts.ildkule.ipv6};
        deny all;
      '';
    };
  };
}
