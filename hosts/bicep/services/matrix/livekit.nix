{ config, lib, fp, ... }:
let
  matrixDomain = "matrix.pvv.ntnu.no";
  cfg = config.services.livekit;
in
{
  sops.secrets."matrix/livekit/keyfile/lk-jwt-service" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "livekit/keyfile/lk-jwt-service";
  };
  sops.templates."matrix-livekit-keyfile" = {
    restartUnits = [
      "livekit.service"
      "lk-jwt-service.service"
    ];
    content = ''
      lk-jwt-service: ${config.sops.placeholder."matrix/livekit/keyfile/lk-jwt-service"}
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
      # Without this, LiveKit auto-creates rooms for any JWT holder,
      # bypassing the full-access-homeserver restriction that
      # lk-jwt-service is supposed to enforce.
      room.auto_create = false;

      # bicep's interface address is already a publicly routable PVV/NTNU
      # IP, but STUN-based discovery is cheap and avoids advertising a
      # wrong ICE candidate if that ever changes (e.g. hypervisor NAT).
      rtc.use_external_ip = true;

      # NOTE: delegated-leave (MSC4140) webhook support only landed in
      # lk-jwt-service v0.6.0; the currently packaged version (0.4.4) has
      # no /sfu_webhook route, so this would be a no-op. Uncomment once
      # the package is bumped to >=0.6.0 (api_key must match the
      # lk-jwt-service key in the shared keyfile).
      # webhook = {
      #   api_key = "lk-jwt-service";
      #   urls = [ "https://${matrixDomain}/livekit/jwt/sfu_webhook" ];
      # };
    };
  };

  services.lk-jwt-service = lib.mkIf cfg.enable {
    enable = true;
    livekitUrl = "wss://${matrixDomain}/livekit/sfu";
    keyFile = config.sops.templates."matrix-livekit-keyfile".path;
  };

  systemd.services.lk-jwt-service = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];

    environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = builtins.concatStringsSep "," [ "pvv.ntnu.no" "dodsorf.as" ];
  };

  services.nginx.virtualHosts.${matrixDomain} = lib.mkIf cfg.enable {
    locations."^~ /livekit/jwt/" = {
      proxyPass = "http://localhost:${toString config.services.lk-jwt-service.port}/";
    };

    # TODO: load balance to multiple livekit ingress/egress workers
    locations."^~ /livekit/sfu/" = {
      proxyPass = "http://localhost:${toString config.services.livekit.settings.port}/";
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
  };
}
