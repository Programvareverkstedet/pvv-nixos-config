{ config, ... }:
let
  cfgTuwunel = config.services.matrix-tuwunel;
in
{
  imports = [
    ./contactPoint.nix
  ];

  sops.secrets."keys/tuwunel/sirenhead/access_token" = {
    restartUnits = [ "${config.services.python-http-handlers.sirenhead.name}.service" ];
  };

  services.python-http-handlers.sirenhead = {
    listenStreams = [ "127.0.0.1:13337" ];
    serviceConfig = {
      LoadCredential = [
        "access_token:${config.sops.secrets."keys/tuwunel/sirenhead/access_token".path}"
      ];
      SupplementaryGroups = [ cfgTuwunel.group ];
    };
    handler = builtins.readFile ./handler.py;
  };

  systemd.services.${config.services.python-http-handlers.sirenhead.name}.environment = {
    TUWUNEL_SOCKET = cfgTuwunel.settings.global.unix_socket_path;
    # #grafana:alerts.pvv.ntnu.no
    ROOM_ID = "!hrLcMhBaGzNkiRSXKKxrugXiluXN8044FjIFwjZqFD4";
  };
}
