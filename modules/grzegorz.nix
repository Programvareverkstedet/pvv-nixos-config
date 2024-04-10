{config, lib, pkgs, ...}:
let
  grg = config.services.grzegorz;
  grgw = config.services.grzegorz-webui;
in {
  services.pipewire.enable = true;
  services.pipewire.alsa.enable = true;
  services.pipewire.alsa.support32Bit = true;
  services.pipewire.pulse.enable = true;

  users.users.pvv = {
    isNormalUser = true;
    description = "pvv";
  };

  services.grzegorz.enable = true;
  services.grzegorz.listenAddr = "localhost";
  services.grzegorz.listenPort = 31337;

  services.grzegorz-webui.enable = true;
  services.grzegorz-webui.listenAddr = "localhost";
  services.grzegorz-webui.listenPort = 42069;
  services.grzegorz-webui.listenWebsocketPort = 42042;
  services.grzegorz-webui.hostName = "${config.networking.fqdn}";
  services.grzegorz-webui.apiBase = "http://${toString grg.listenAddr}:${toString grg.listenPort}/api";

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
      proxyPass = "http://localhost:${builtins.toString config.services.grzegorz-webui.listenPort}";
    };
    # https://github.com/rawpython/remi/issues/216
    locations."/websocket" = {
      proxyPass = "http://localhost:${builtins.toString config.services.grzegorz-webui.listenWebsocketPort}";
      proxyWebsockets = true;
    };
    locations."/api" = {
      proxyPass = "http://localhost:${builtins.toString config.services.grzegorz.listenPort}";
    };
    locations."/docs" = {
      proxyPass = "http://localhost:${builtins.toString config.services.grzegorz.listenPort}";
    };
  };

}

