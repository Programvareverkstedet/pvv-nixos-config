{ config, lib, ... }:

let
  cfg = config.services.mx-puppet-discord;
in
{
  users.groups.keys-matrix-registrations = { };

  sops.secrets."matrix/discord/as_token" = {
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    key = "discord/as_token";
  };
  sops.secrets."matrix/discord/hs_token" = {
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    key = "discord/hs_token";
  };

  sops.templates."discord-registration.yaml" = {
    owner = config.users.users.matrix-synapse.name;
    group = config.users.groups.keys-matrix-registrations.name;
    content = ''
      as_token: "${config.sops.placeholder."matrix/discord/as_token"}"
      hs_token: "${config.sops.placeholder."matrix/discord/hs_token"}"
      id: discord-puppet
      namespaces:
        users:
          - exclusive: true
            regex: '@_discordpuppet_.*'
        rooms: []
        aliases:
          - exclusive: true
            regex: '#_discordpuppet_.*'
      protocols: []
      rate_limited: false
      sender_localpart: _discordpuppet_bot
      url: 'http://localhost:8434'
      de.sorunome.msc2409.push_ephemeral: true
    '';
  };

  systemd.services.mx-puppet-discord = {
    serviceConfig.SupplementaryGroups = [
      config.users.groups.keys-matrix-registrations.name
    ];
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
  services.mx-puppet-discord.serviceDependencies = [
    "matrix-synapse.target"
    "nginx.service"
  ];


  services.matrix-synapse-next.settings = {
    app_service_config_files = [
      config.sops.templates."discord-registration.yaml".path
    ];
    use_appservice_legacy_authorization = true;
  };

}
