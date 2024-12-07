{ config, lib, fp, unstablePkgs, inputs, ... }:

let
  cfg = config.services.matrix-hookshot;
  webhookListenAddress = "127.0.0.1";
  webhookListenPort = 8435;
in
{
  sops.secrets."matrix/hookshot/as_token" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "hookshot/as_token";
  };
  sops.secrets."matrix/hookshot/hs_token" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "hookshot/hs_token";
  };

  sops.templates."hookshot-registration.yaml" = {
    owner = config.users.users.matrix-synapse.name;
    group = config.users.groups.keys-matrix-registrations.name;
    content = ''
      id: matrix-hookshot
      as_token: "${config.sops.placeholder."matrix/hookshot/as_token"}"
      hs_token: "${config.sops.placeholder."matrix/hookshot/hs_token"}"
      namespaces:
        rooms: []
        users:
          - regex: "@_webhooks_.*:pvv.ntnu.no"
            exclusive: true
          - regex: "@bot_feeds:pvv.ntnu.no"
            exclusive: true
        aliases: []

      sender_localpart: hookshot
      url: "http://${cfg.settings.bridge.bindAddress}:${toString cfg.settings.bridge.port}"
      rate_limited: false

      # If enabling encryption
      de.sorunome.msc2409.push_ephemeral: true
      push_ephemeral: true
      org.matrix.msc3202: true
    '';
  };

  systemd.services.matrix-hookshot = {
    serviceConfig.SupplementaryGroups = [
      config.users.groups.keys-matrix-registrations.name
    ];
  };

  services.matrix-hookshot = {
    enable = true;
    package = unstablePkgs.matrix-hookshot;
    registrationFile = config.sops.templates."hookshot-registration.yaml".path;
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

  services.matrix-hookshot.serviceDependencies = [
    "matrix-synapse.target"
    "nginx.service"
  ];

  services.matrix-synapse-next.settings = {
    app_service_config_files = [
      config.sops.templates."hookshot-registration.yaml".path
    ];
  };

  services.nginx.virtualHosts."hookshot.pvv.ntnu.no" = {
    enableACME = true;
    locations."/" = {
      proxyPass = "http://${webhookListenAddress}:${toString webhookListenPort}";
    };
  };
}
