{ config, lib, unstablePkgs, inputs, ... }:

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
        domain = "pvv.ntnu,no";
        url = "https://matrix.pvv.ntnu.no";
        mediaUrl = "https://matrix.pvv.ntnu.no";
        port = 9993;
      };
      listeners = [
        {
          bindAddress = "127.0.0.1";
          port = 9000;
          resources = [
            "webhooks"
            "metrics"
            "provisioning"
            "widgets"
          ];
        }
      ];
      generic = {
        enabled = true;
      };
      feeds = {
        enabled = true;
      };
    };
  };

  services.matrix-hookshot.serviceDependencies = [ "matrix-synapse.target" "nginx.service" ];

  services.matrix-synapse-next.settings = {
    app_service_config_files = [ config.sops.secrets."matrix/registrations/matrix-hookshot".path ];
  };
}
