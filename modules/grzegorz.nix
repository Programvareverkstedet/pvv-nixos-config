{config, lib, pkgs, ...}:
let
  grg = config.services.greg-ng;
  grgw = config.services.grzegorz-webui;
in {
  services.greg-ng = {
    enable = true;
    settings.host = "localhost";
    settings.port = 31337;
    enableSway = true;
    enablePipewire = true;
  };

  services.grzegorz-webui = {
    enable = true;
    listenAddr = "localhost";
    listenPort = 42069;
    listenWebsocketPort = 42042;
    hostName = "${config.networking.fqdn}";
    apiBase = "http://${grg.settings.host}:${toString grg.settings.port}/api";
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts."${config.networking.fqdn}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    serverAliases = [
      "${config.networking.hostName}.pvv.org"
    ];
    extraConfig = ''
      allow 129.241.210.128/25;
      allow 2001:700:300:1900::/64;
      deny all;
    '';

    locations."/" = {
      proxyPass = "http://${grgw.listenAddr}:${toString grgw.listenPort}";
    };
    # https://github.com/rawpython/remi/issues/216
    locations."/websocket" = {
      proxyPass = "http://${grgw.listenAddr}:${toString grgw.listenWebsocketPort}";
      proxyWebsockets = true;
    };
    locations."/api" = {
      proxyPass = "http://${grg.settings.host}:${toString grg.settings.port}";
    };
    locations."/docs" = {
      proxyPass = "http://${grg.settings.host}:${toString grg.settings.port}";
    };
  };
}

