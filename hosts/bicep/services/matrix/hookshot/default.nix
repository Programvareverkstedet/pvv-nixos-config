{ config, lib, unstablePkgs, inputs, ... }:

let
  cfg = config.services.matrix-hookshot;
  webhookListenAddress = "127.0.0.1";
  webhookListenPort = 8435;
in
{
  imports = [
    ./module.nix
  ];

  sops.secrets."matrix/registrations/matrix-hookshot" = {
    sopsFile = ../../../../../secrets/bicep/matrix.yaml;
    key = "registrations/matrix-hookshot";
    owner = config.users.users.matrix-synapse.name;
    group = config.users.groups.keys-matrix-registrations.name;
  };

  systemd.services.matrix-hookshot = {
    serviceConfig.SupplementaryGroups = [ config.users.groups.keys-matrix-registrations.name ];
  };

  services.matrix-hookshot = {
    enable = true;
    package = unstablePkgs.matrix-hookshot;
    registrationFile = config.sops.secrets."matrix/registrations/matrix-hookshot".path;
    settings = {
      bridge = {
        bindAddress = "127.0.0.1";
        domain = "pvv.ntnu.no";
        url = "https://matrix.pvv.ntnu.no";
        mediaUrl = "https://matrix.pvv.ntnu.no";
        port = 9993;
      };
      listeners = [
        {
          bindAddress = webhookListenAddress;
          port = webhookListenPort;
          resources = [
            "webhooks"
            # "metrics"
            # "provisioning"
            "widgets"
          ];
        }
      ];
      generic = {
        enabled = true;
        outbound = true;
        urlPrefix = "https://hookshot.pvv.ntnu.no/webhook/";
        userIdPrefix = "_webhooks_";
        allowJsTransformationFunctions = false;
        waitForComplete = false;
      };
      feeds = {
        enabled = true;
        pollIntervalSeconds = 600;
      };
      
      serviceBots = [
        { localpart = "bot_feeds";
          displayname = "Aya";
          avatar = ./feeds.png;
          prefix = "!aya";
          service = "feeds";
        }
      ];

      permissions = [
        # Users of the PVV Server
        { actor = "pvv.ntnu.no";
          services = [ { service = "*"; level = "commands"; } ];
        }
        # Members of Medlem space (for people with their own hs)
        { actor = "!pZOTJQinWyyTWaeOgK:pvv.ntnu.no";
          services = [ { service = "*"; level = "commands"; } ];
        }
        # Members of Drift
        { actor = "!eYgeufLrninXxQpYml:pvv.ntnu.no";
          services = [ { service = "*"; level = "admin"; } ];
        }
        # Dan bootstrap
        { actor = "@dandellion:dodsorf.as";
          services = [ { service = "*"; level = "admin"; } ];
        }
      ];
    };
  };

  services.matrix-hookshot.serviceDependencies = [ "matrix-synapse.target" "nginx.service" ];

  services.matrix-synapse-next.settings = {
    app_service_config_files = [ config.sops.secrets."matrix/registrations/matrix-hookshot".path ];
  };

  services.nginx.virtualHosts."hookshot.pvv.ntnu.no" = {
    enableACME = true;
    locations."/" = {
      proxyPass = "http://${webhookListenAddress}:${toString webhookListenPort}";
    };
  };
}
