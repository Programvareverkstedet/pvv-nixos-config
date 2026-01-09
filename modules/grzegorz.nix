{config, lib, pkgs, unstablePkgs, values, ...}:
let
  grg = config.services.greg-ng;
  grgw = config.services.grzegorz-webui;

  machine = config.networking.hostName;
in {
  services.greg-ng = {
    enable = true;
    settings.host = "localhost";
    settings.port = 31337;
    enableSway = true;
    enablePipewire = true;

    mpvPackage = unstablePkgs.mpv;
  };

  systemd.user.services.restart-greg-ng = {
    script = "systemctl --user restart greg-ng.service";
    startAt = "*-*-* 06:30:00";
  };

  services.grzegorz-webui = {
    enable = true;
    listenAddr = "localhost";
    listenPort = 42069;
    listenWebsocketPort = 42042;
    hostName = "${machine}-old.pvv.ntnu.no";
    apiBase = "https://${machine}-backend.pvv.ntnu.no/api";
  };

  services.gergle = {
    enable = true;
    virtualHost = config.networking.fqdn;
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    ${config.networking.fqdn} = {
      forceSSL = true;
      enableACME = true;
      kTLS = true;
      serverAliases = [
        "${machine}.pvv.org"
      ];
      extraConfig = ''
        # pvv
        allow ${values.ipv4-space};
        allow ${values.ipv6-space};
        # ntnu
        allow ${values.ntnu.ipv4-space};
        allow ${values.ntnu.ipv6-space};
        deny all;
      '';

      locations."/docs" = {
        proxyPass = "http://${grg.settings.host}:${toString grg.settings.port}";
      };

      locations."/api" = {
        proxyPass = "http://${grg.settings.host}:${toString grg.settings.port}";
        proxyWebsockets = true;
      };
    };

    "${machine}-backend.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;
      kTLS = true;
      serverAliases = [
        "${machine}-backend.pvv.org"
      ];
      extraConfig = ''
        # pvv
        allow ${values.ipv4-space};
        allow ${values.ipv6-space};
        # ntnu
        allow ${values.ntnu.ipv4-space};
        allow ${values.ntnu.ipv6-space};
        deny all;
      '';

      locations."/" = {
        proxyPass = "http://${grg.settings.host}:${toString grg.settings.port}";
        proxyWebsockets = true;
      };
    };

    "${machine}-old.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;
      kTLS = true;
      serverAliases = [
        "${machine}-old.pvv.org"
      ];
      extraConfig = ''
        # pvv
        allow ${values.ipv4-space};
        allow ${values.ipv6-space};
        # ntnu
        allow ${values.ntnu.ipv4-space};
        allow ${values.ntnu.ipv6-space};
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
  };
}

