{ config, pkgs, fp, ... }:
let
  cfg = config.services.matrix-ooye;
in
{
  users.groups.keys-matrix-registrations = { };

  sops.secrets = {
    "matrix/ooye/as_token" = {
      sopsFile = fp /secrets/bicep/matrix.yaml;
      key = "ooye/as_token";
    };
    "matrix/ooye/hs_token" = {
      sopsFile = fp /secrets/bicep/matrix.yaml;
      key = "ooye/hs_token";
    };
    "matrix/ooye/discord_token" = {
      sopsFile = fp /secrets/bicep/matrix.yaml;
      key = "ooye/discord_token";
    };
    "matrix/ooye/discord_client_secret" = {
      sopsFile = fp /secrets/bicep/matrix.yaml;
      key = "ooye/discord_client_secret";
    };
  };

  services.matrix-ooye = {
    enable = true;
    homeserver = "https://matrix.pvv.ntnu.no";
    homeserverName = "matrix.pvv.ntnu.no";
    discordTokenPath = config.sops.secrets."matrix/ooye/discord_token".path;
    discordClientSecretPath = config.sops.secrets."matrix/ooye/discord_client_secret".path;
    bridgeOrigin = "https://ooye.pvv.ntnu.no";

    enableSynapseIntegration = false;
  };

  systemd.services."matrix-synapse" = {
    after = [
      "matrix-ooye-pre-start.service"
      "network-online.target"
    ];
    requires = [ "matrix-ooye-pre-start.service" ];
    serviceConfig = {
      LoadCredential = [
        "matrix-ooye-registration:/var/lib/matrix-ooye/registration.yaml"
      ];
      ExecStartPre = [
        "+${pkgs.coreutils}/bin/cp /run/credentials/matrix-synapse.service/matrix-ooye-registration ${config.services.matrix-synapse-next.dataDir}/ooye-registration.yaml"
        "+${pkgs.coreutils}/bin/chown matrix-synapse:keys-matrix-registrations ${config.services.matrix-synapse-next.dataDir}/ooye-registration.yaml"
      ];
    };
  };

  services.matrix-synapse-next.settings = {
    app_service_config_files = [
      "${config.services.matrix-synapse-next.dataDir}/ooye-registration.yaml"
    ];
  };

  services.nginx.virtualHosts."ooye.pvv.ntnu.no" = {
    locations."/".proxyPass = "http://localhost:${cfg.socket}";
  };
}
