{ config, lib, ... }:

let
  cfg = config.services.mx-puppet-discord;
in
{
  users.groups.keys-matrix-registrations = { };

  sops.secrets."matrix/registrations/mx-puppet-discord" = {
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    key = "registrations/mx-puppet-discord";
    owner = config.users.users.matrix-synapse.name;
    group = config.users.groups.keys-matrix-registrations.name;
  };

  systemd.services.mx-puppet-discord = {
    serviceConfig.SupplementaryGroups = [ config.users.groups.keys-matrix-registrations.name ];
  };


  services.mx-puppet-discord.enable = true;
  services.mx-puppet-discord.settings = {
    bridge = {
      bindAddress = "localhost";
      domain = "pvv.ntnu.no";
      homeserverUrl = "https://matrix.pvv.ntnu.no";
    };
    provisioning.whitelist = [ "@dandellion:dodsorf\\.as" "@danio:pvv\\.ntnu\\.no"];
    relay.whitelist = [ ".*" ];
    selfService.whitelist = [ "@danio:pvv\\.ntnu\\.no" "@dandellion:dodsorf\\.as" ];
  };
  services.mx-puppet-discord.serviceDependencies = [ "matrix-synapse.target" "nginx.service" ];


  services.matrix-synapse-next.settings.app_service_config_files = [ config.sops.secrets."matrix/registrations/mx-puppet-discord".path ];

}
