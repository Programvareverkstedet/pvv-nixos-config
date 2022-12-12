{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.pvv.minecraft-server-fabric;
  
  # We don't allow eula=false anyways
  eulaFile = builtins.toFile "eula.txt" ''
    # eula.txt managed by NixOS Configuration
    eula=true
  '';
  
  whitelistFile = pkgs.writeText "whitelist.json"
    (builtins.toJSON
      (mapAttrsToList (n: v: { name = n; uuid = v; }) cfg.whitelist));

  cfgToString = v: if builtins.isBool v then boolToString v else toString v;
  
  serverPropertiesFile = pkgs.writeText "server.properties" (''
    # server.properties managed by NixOS configuration
  '' + concatStringsSep "\n" (mapAttrsToList
    (n: v: "${n}=${cfgToString v}") cfg.serverProperties));
  
  defaultServerPort = 25565;

  serverPort = cfg.serverProperties.server-port or defaultServerPort;

  rconPort = if cfg.serverProperties.enable-rcon or false
    then cfg.serverProperties."rcon.port" or 25575
    else null;

  queryPort = if cfg.serverProperties.enable-query or false
    then cfg.serverProperties."query.port" or 25565
    else null;

in
{

  options.pvv.minecraft-server-fabric = {
    enable = mkEnableOption "minecraft-server-fabric";

    package = mkOption {
      type = types.package;
    };

    eula = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether you agree to
        <link xlink:href="https://account.mojang.com/documents/minecraft_eula">
        Mojangs EULA</link>. This option must be set to
        <literal>true</literal> to run Minecraft server.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/minecraft-fabric";
      description = ''
        Directory to store Minecraft database and other state/data files.
      '';
    };


    whitelist = mkOption {
      type = let
        minecraftUUID = types.strMatching
          "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" // {
            description = "Minecraft UUID";
          };
        in types.attrsOf minecraftUUID;
      default = {};
      description = ''
        Whitelisted players, only has an effect when
        <option>services.minecraft-server.declarative</option> is
        <literal>true</literal> and the whitelist is enabled
        via <option>services.minecraft-server.serverProperties</option> by
        setting <literal>white-list</literal> to <literal>true</literal>.
        This is a mapping from Minecraft usernames to UUIDs.
        You can use <link xlink:href="https://mcuuid.net/"/> to get a
        Minecraft UUID for a username.
      '';
      example = literalExpression ''
        {
          username1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
          username2 = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
        };
      '';
    };

    serverProperties = mkOption {
      type = with types; attrsOf (oneOf [ bool int str ]);
      default = {};
      example = literalExpression ''
        {
          server-port = 43000;
          difficulty = 3;
          gamemode = 1;
          max-players = 5;
          motd = "NixOS Minecraft server!";
          white-list = true;
          enable-rcon = true;
          "rcon.password" = "hunter2";
        }
      '';
      description = ''
        Minecraft server properties for the server.properties file. Only has
        an effect when <option>services.minecraft-server.declarative</option>
        is set to <literal>true</literal>. See
        <link xlink:href="https://minecraft.gamepedia.com/Server.properties#Java_Edition_3"/>
        for documentation on these values.
      '';
    };

    jvmOpts = mkOption {
      type = types.separatedString " ";
      default = "-Xmx2048M -Xms2048M";
      # Example options from https://minecraft.gamepedia.com/Tutorials/Server_startup_script
      example = "-Xmx2048M -Xms4092M -XX:+UseG1GC -XX:+CMSIncrementalPacing "
        + "-XX:+CMSClassUnloadingEnabled -XX:ParallelGCThreads=2 "
        + "-XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10";
      description = "JVM options for the Minecraft server.";
    };

    mods = mkOption {
      type = types.listOf types.package;
      example = literalExpression ''
        [
          (pkgs.fetchurl {
            url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/0.44.0+1.18/fabric-api-0.44.0+1.18.jar";
            sha256 = "0mlmj7mj073a48s8zgc1km0jwkphz01c1fvivn4mw37lbm2p4834";
          })
        ];
      '';
      description = "List of mods to put in the mods folder";
    };
  };

  config = mkIf cfg.enable {
    users.users.minecraft = {
      description     = "Minecraft server service user";
      home            = cfg.dataDir;
      createHome      = true;
      isSystemUser    = true;
      group           = "minecraft";
    };
    users.groups.minecraft = {};

    systemd.services.minecraft-server-fabric = {
      description   = "Minecraft Server Service";
      wantedBy      = [ "multi-user.target" ];
      after         = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/minecraft-server ${cfg.jvmOpts}";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = cfg.dataDir;
      };

      preStart = ''
        ln -sf ${eulaFile} eula.txt
        ln -sf ${whitelistFile} whitelist.json
        cp -f ${serverPropertiesFile} server.properties

        ln -sfn ${pkgs.linkFarmFromDrvs "fabric-mods" cfg.mods} mods
      '';
    };

    assertions = [
      { assertion = cfg.eula;
        message = "You must agree to Mojangs EULA to run minecraft-server."
          + " Read https://account.mojang.com/documents/minecraft_eula and"
          + " set `services.minecraft-server.eula` to `true` if you agree.";
      }
    ]; 
  };
}
