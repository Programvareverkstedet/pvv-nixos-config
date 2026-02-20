# Original from: https://cgit.rory.gay/nix/OOYE-module.git/

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.matrix-ooye;
  mkStringOption =
    name: default:
    lib.mkOption {
      type = lib.types.str;
      default = default;
    };
in
{
  options = {
    services.matrix-ooye = {
      enable = lib.mkEnableOption "Enable OOYE service";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.out-of-your-element;
      };
      appserviceId = mkStringOption "The ID of the appservice." "ooye";
      homeserver = mkStringOption "The homeserver to connect to." "http://localhost:8006";
      homeserverName = mkStringOption "The name of the homeserver to connect to." "localhost";
      namespace = mkStringOption "The prefix to use for the MXIDs/aliases of bridged users/rooms. Should end with a _!" "_ooye_";
      discordTokenPath = mkStringOption "The path to the discord token file." "/etc/ooye-discord-token";
      discordClientSecretPath = mkStringOption "The path to the discord token file." "/etc/ooye-discord-client-secret";
      socket = mkStringOption "The socket to listen on, can either be a port number or a unix socket path." "6693";
      bridgeOrigin = mkStringOption "The web frontend URL for the bridge, defaults to http://localhost:{socket}" "";

      enableSynapseIntegration = lib.mkEnableOption "Enable Synapse integration";
    };
  };
  config = lib.mkIf cfg.enable (
    let
      baseConfig = pkgs.writeText "matrix-ooye-config.json" (
        builtins.toJSON {
          id = cfg.appserviceId;
          namespaces = {
            users = [
              {
                exclusive = true;
                regex = "@${cfg.namespace}.*:${cfg.homeserverName}";
              }
            ];
            aliases = [
              {
                exclusive = true;
                regex = "#${cfg.namespace}.*:${cfg.homeserverName}";
              }
            ];
          };
          protocols = [ "discord" ];
          sender_localpart = "${cfg.namespace}bot";
          rate_limited = false;
          socket = cfg.socket; # Can either be a TCP port or a unix socket path
          url =
            if (lib.hasPrefix "/" cfg.socket) then "unix:${cfg.socket}" else "http://localhost:${cfg.socket}";
          ooye = {
            server_name = cfg.homeserverName;
            namespace_prefix = cfg.namespace;
            max_file_size = 5000000;
            content_length_workaround = false;
            include_user_id_in_mxid = true;
            server_origin = cfg.homeserver;
            bridge_origin =
              if (cfg.bridgeOrigin == "") then "http://localhost:${cfg.socket}" else cfg.bridgeOrigin;
          };
        }
      );

      script = pkgs.writeScript "matrix-ooye-pre-start.sh" ''
        #!${lib.getExe pkgs.bash}
        REGISTRATION_FILE=registration.yaml

        id
        echo "Before if statement"
        stat ''${REGISTRATION_FILE}

        if [[ ! -f ''${REGISTRATION_FILE} ]]; then
          echo "No registration file found at '$REGISTRATION_FILE'"
          cp --no-preserve=mode,ownership ${baseConfig} ''${REGISTRATION_FILE}
        fi

        echo "After if statement"
        stat ''${REGISTRATION_FILE}

        AS_TOKEN=$(${lib.getExe pkgs.jq} -r .as_token ''${REGISTRATION_FILE})
        HS_TOKEN=$(${lib.getExe pkgs.jq} -r .hs_token ''${REGISTRATION_FILE})
        DISCORD_TOKEN=$(cat /run/credentials/matrix-ooye-pre-start.service/discord_token)
        DISCORD_CLIENT_SECRET=$(cat /run/credentials/matrix-ooye-pre-start.service/discord_client_secret)

        # Check if we have all required tokens
        if [[ -z "$AS_TOKEN" || "$AS_TOKEN" == "null" ]]; then
          AS_TOKEN=$(${lib.getExe pkgs.openssl} rand -hex 64)
          echo "Generated new AS token: ''${AS_TOKEN}"
        fi

        if [[ -z "$HS_TOKEN" || "$HS_TOKEN" == "null" ]]; then
          HS_TOKEN=$(${lib.getExe pkgs.openssl} rand -hex 64)
          echo "Generated new HS token: ''${HS_TOKEN}"
        fi

        if [[ -z "$DISCORD_TOKEN" ]]; then
          echo "No Discord token found at '${cfg.discordTokenPath}'"
          echo "You can find this on the 'Bot' tab of your Discord application."
          exit 1
        fi

        if [[ -z "$DISCORD_CLIENT_SECRET" ]]; then
          echo "No Discord client secret found at '${cfg.discordTokenPath}'"
          echo "You can find this on the 'OAuth2' tab of your Discord application."
          exit 1
        fi

        shred -u ''${REGISTRATION_FILE}
        cp --no-preserve=mode,ownership ${baseConfig} ''${REGISTRATION_FILE}

        ${lib.getExe pkgs.jq} '.as_token = "'$AS_TOKEN'" | .hs_token = "'$HS_TOKEN'" | .ooye.discord_token = "'$DISCORD_TOKEN'" | .ooye.discord_client_secret = "'$DISCORD_CLIENT_SECRET'"' ''${REGISTRATION_FILE} > ''${REGISTRATION_FILE}.tmp

        shred -u ''${REGISTRATION_FILE}
        mv ''${REGISTRATION_FILE}.tmp ''${REGISTRATION_FILE}
      '';

    in
    {
      warnings =
        lib.optionals ((builtins.substring (lib.stringLength cfg.namespace - 1) 1 cfg.namespace) != "_") [
          "OOYE namespace does not end with an underscore! This is recommended to have better ID formatting. Provided: '${cfg.namespace}'"
        ]
        ++ lib.optionals ((builtins.substring 0 1 cfg.namespace) != "_") [
          "OOYE namespace does not start with an underscore! This is recommended to avoid conflicts with registered users. Provided: '${cfg.namespace}'"
        ];

      environment.systemPackages = [ cfg.package ];

      systemd.services."matrix-ooye-pre-start" = {
        enable = true;
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = script;
          WorkingDirectory = "/var/lib/matrix-ooye";
          StateDirectory = "matrix-ooye";
          DynamicUser = true;
          RemainAfterExit = true;
          Type = "oneshot";

          LoadCredential = [
            "discord_token:${cfg.discordTokenPath}"
            "discord_client_secret:${cfg.discordClientSecretPath}"
          ];
        };
      };

      systemd.services."matrix-ooye" = {
        enable = true;
        description = "Out of Your Element - a Discord bridge for Matrix.";

        wants = [
          "network-online.target"
          "matrix-synapse.service"
          "conduit.service"
          "dendrite.service"
        ];
        after = [
          "matrix-ooye-pre-start.service"
          "network-online.target"
        ];
        requires = [ "matrix-ooye-pre-start.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = lib.getExe config.services.matrix-ooye.package;
          WorkingDirectory = "/var/lib/matrix-ooye";
          StateDirectory = "matrix-ooye";
          #ProtectSystem = "strict";
          #ProtectHome = true;
          #PrivateTmp = true;
          #NoNewPrivileges = true;
          #PrivateDevices = true;
          Restart = "on-failure";
          RestartSec = "5s";
          StartLimitIntervalSec = "5s";
          StartLimitBurst = "5";
          DynamicUser = true;
        };
      };

      systemd.services."matrix-synapse" = lib.mkIf cfg.enableSynapseIntegration {

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
            "+${pkgs.coreutils}/bin/cp /run/credentials/matrix-synapse.service/matrix-ooye-registration ${config.services.matrix-synapse.dataDir}/ooye-registration.yaml"
            "+${pkgs.coreutils}/bin/chown matrix-synapse:matrix-synapse ${config.services.matrix-synapse.dataDir}/ooye-registration.yaml"
          ];
        };
      };

      services.matrix-synapse.settings.app_service_config_files = lib.mkIf cfg.enableSynapseIntegration [
        "${config.services.matrix-synapse.dataDir}/ooye-registration.yaml"
      ];
    }
  );
}
