{config, lib, pkgs, ... }:

{

  imports = [ ./minecraft-server-fabric.nix ];

  pvv.minecraft-server-fabric = {
    enable = true;
    eula = true;

    package = pkgs.callPackage ../../pkgs/minecraft-server-fabric { inherit (pkgs.unstable) minecraft-server; };
    jvmOpts = "-Xms10G -Xmx10G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC  -XX:+DisableExplicitGC  -XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled";

    serverProperties = {
      view-distance = 32;
      gamemode = 1;
      enable-rcon = true;
      "rcon.password" = "pvv";
    };

    dataDir = "/fast/minecraft-fabric";

    mods = [
      (pkgs.fetchurl { # Fabric API is a common dependency for fabric based mods
        url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/0.44.0+1.18/fabric-api-0.44.0+1.18.jar";
        sha256 = "0mlmj7mj073a48s8zgc1km0jwkphz01c1fvivn4mw37lbm2p4834";
      })
      (pkgs.fetchurl { # Lithium is a 100% vanilla compatible optimization mod
        url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/mc1.18.1-0.7.6/lithium-fabric-mc1.18.1-0.7.6.jar";
        sha256 = "1fw1ikg578v4i6bmry7810a3q53h8yspxa3awdz7d746g91g8lf7";
      })
      (pkgs.fetchurl { # Starlight is the lighting engine of papermc
        url = "https://cdn.modrinth.com/data/H8CaAYZC/versions/Starlight%201.0.0%201.18.x/starlight-1.0.0+fabric.d0a3220.jar";
        sha256 = "0bv9im45hhc8n6x57lakh2rms0g5qb7qfx8qpx8n6mbrjjz6gla1";
      })
      (pkgs.fetchurl { # Krypton is a linux optimized optimizer for minecrafts networking system
        url = "https://cdn.modrinth.com/data/fQEb0iXm/versions/0.1.6/krypton-0.1.6.jar";
        sha256 = "1ribvbww4msrfdnzlxipk8kpzz7fnwnd4q6ln6mpjlhihcjb3hni";
      })
      (pkgs.fetchurl { # C2ME is a parallelizer for chunk loading and generation, experimental!!!
        url = "https://cdn.modrinth.com/data/VSNURh3q/versions/0.2.0+alpha.5.104%201.18.1/c2me-fabric-mc1.18.1-0.2.0+alpha.5.104-all.jar";
        sha256 = "13zrpsg61fynqnnlm7dvy3ihxk8khlcqsif68ak14z7kgm4py6nw";
      })
      (pkgs.fetchurl { # Spark is a profiler for minecraft
        url = "https://ci.lucko.me/job/spark/251/artifact/spark-fabric/build/libs/spark-fabric.jar";
        sha256 = "1clvi5v7a14ba23jbka9baz99h6wcfjbadc8kkj712fmy2h0sx07";
      })
      (pkgs.fetchurl { # Carpetmod gives you tps views in the tab menu,
        # but also adds a lot of optional serverside vanilla+ features (which we arent using).
        # So probably want something else
        url = "https://github.com/gnembon/fabric-carpet/releases/download/1.4.56/fabric-carpet-1.18-1.4.56+v211130.jar";
        sha256 = "0rvl2yb8xymla8c052j07gqkqfkz4h5pxf6aip2v9v0h8r84p9hf";
      })
    ];
  };

  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];

  systemd.services."minecraft-backup" = {
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.mcrcon}/bin/mcrcon -p pvv "say Starting Backup" "save-off" "save-all"
      ${pkgs.rsync}/bin/rsync -avz --delete ${config.pvv.minecraft-server-fabric.dataDir}/world /fast/backup # Where to put backup
      ${pkgs.mcrcon}/bin/mcrcon -p pvv "save-all" "say Completed Backup" "save-on" "save-all"
    '';
  };

  systemd.timers."minecraft-backup" = {
    wantedBy = ["timers.target"];
    timerConfig.OnCalendar = [ "hourly" ];
  };

}
