{config, lib, pkgs, ... }:

{

  imports = [ ./minecraft-server-fabric.nix ];

  pvv.minecraft-server-fabric = {
    enable = true;
    eula = true;

    package = pkgs.callPackage ../../pkgs/minecraft-server-fabric { inherit (pkgs.unstable) minecraft-server; };
    jvmOpts = "-Xms10G -Xmx10G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC  -XX:+DisableExplicitGC  -XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled";

    serverProperties = {
      view-distance = 10;
      simulation-distance = 10;

      enable-command-block = true;

      gamemode = "survival";
      difficulty = "normal";
      
      white-list = true;

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

    whitelist = {
      gunalx = "913a21ae-3a11-4178-a192-401490ca0891";
      eirikwitt = "1689e626-1cc8-4b91-81c4-0632fd34eb19";
      Rockj = "202c0c91-a4e0-4b45-8c1b-fc51a8956c0a";
      paddishar = "326845aa-4b45-4cd9-8108-7816e10a9828";
      nordyorn = "f253cddf-a520-42ab-85d3-713992746e42";
      hell04 = "c681df2a-6a30-4c66-b70d-742eb68bbc04";
      steinarh = "bd8c419e-e6dc-4fc5-ac62-b92f98c1abc9";
      EastTown2000 = "f273ed2e-d3ba-43fc-aff4-3e800cdf25e1";
      DirDanner = "5b5476a2-1138-476b-9ff1-1f39f834a428";
      asgeirbj = "dbd5d89f-3d8a-4662-ad15-6c4802d0098f";
      Linke03 = "0dbc661d-898a-47ff-a371-32b7bd76b78b";
      somaen = "cc0bdd13-4304-4160-80e7-8f043446fa83";
      einaman = "39f45df3-423d-4274-9ef9-c9b7575e3804";
      liseu = "c8f4d9d8-3140-4c35-9f66-22bc351bb7e6";
      torsteno = "ae1e7b15-a0de-4244-9f73-25b68427e34a";
      simtind = "39c03c95-d628-4ccc-843d-ce1332462d9e";
      aellaie = "c585605d-24bb-4d75-ba9c-0064f6a39328";
      PerKjelsvik = "5df69f17-27c9-4426-bcae-88b435dfae73";
      CelestialCry = "9e34d192-364e-4566-883a-afc868c4224d";
      terjesc = "993d70e8-6f9b-4094-813c-050d1a90be62";
      maxelost = "bf465915-871a-4e3e-a80c-061117b86b23";
      4ce1 = "8a9b4926-0de8-43f0-bcde-df1442dee1d0";
      exponential = "1ebcca9d-0964-48f3-9154-126a9a7e64f6";
      Dodsorbot = "3baa9d58-32e4-465e-80bc-9dcb34e23e1d";
      HFANTOM = "cd74d407-7fb0-4454-b3f4-c0b4341fde18";
      Ghostmaker = "96465eee-e665-49ab-9346-f12d5a040624";
      soonhalle = "61a8e674-7c7a-4120-80d1-4453a5993350";
      MasterMocca = "481e6dac-9a17-4212-9664-645c3abe232f";
      soulprayfree = "cfb1fb23-5115-4fe2-9af9-00a02aea9bf8";
      calibwam = "0d5d5209-bb7c-4006-9451-fb85d7d52618";
      Skuggen = "f0ccee0b-741a-413a-b8e6-d04552b9d78a";
      Sivertsen3 = "cefac1a6-52a7-4781-be80-e7520f758554";
      vafflonaut = "4d864d5c-74e2-4f29-b57d-50dea76aaabd";
      Dhila = "c71d6c23-14d7-4daf-ae59-cbf0caf45681";
      remorino = "2972ab22-96b3-462d-ab4d-9b6b1775b9bb";
      SamuelxJackson = "f140e4aa-0a19-48ab-b892-79b24bd82c1e";
      ToanBuiDuc = "a3c54742-4caf-4334-8bbb-6402a8eb4268";
      Joces123 = "ecbcfbf9-9bcc-49f0-9435-f2ac2b3217c1";
      brunsviken = "75ff5f0e-8adf-4807-a7f0-4cb66f81cb7f";
      oscarsb1 = "9460015a-65cc-4a2f-9f91-b940b6ce7996";
      CVi = "6f5691ce-9f9c-4310-84aa-759d2f9e138e";
      Tawos = "0b98e55c-10cf-4b23-85d3-d15407431ace";
      evenhunn = "8751581b-cc5f-4f8b-ae1e-34d90127e074";
      q41 = "a080e5b4-10ee-4d6f-957e-aa5053bb1046";
      jesper001 = "fbdf3ceb-eaa9-4aeb-94c2-a587cde41774";
      finninde = "f58afd00-28cd-48dd-a74a-6c1d76b57f66";
      GameGuru999 = "535f2188-a4a4-4e54-bec6-74977bee09ab";
      MinusOneKelvin = "b6b973bf-1e35-4a58-803b-a555fd90a172";
      SuperRagna = "e2c32136-e510-41b1-84c0-41baeccfb0b9";
      Zamazaki = "d4411eca-401a-4565-9451-5ced6f48f23f";
      supertheodor = "610c4e86-0ecc-4e7a-bffc-35a2e7d90aa6";
      Minelost = "22ae2a1f-cfd9-4f10-9e41-e7becd34aba8";
      Bjand = "aed136b6-17f7-4ce1-8a7b-a09eb1694ccf";
      Dandellion = "f393413b-59fc-49d7-a5c4-83a5d177132c";
      Shogori = "f9d571bd-5754-46e8-aef8-e89b38a6be9b";
      Caragath = "f8d34f3a-55c3-4adc-b8d8-73a277f979e8";
      Shmaapqueen = "425f2eef-1a9d-4626-9ba3-cd58156943dc";
      Liquidlif3 = "420482b3-885f-4951-ba1e-30c22438a7e0";
      newtonseple = "7d8bf9ca-0499-4cb7-9d6a-daabf80482b6";
      nainis = "2eaf3736-decc-4e11-9a44-af2df0ee7c81";
      Devolan = "87016228-76b2-434f-a963-33b005ae9e42";
      zSkyler = "c92169e4-ca14-4bd5-9ea2-410fe956abe2";
      Cryovat = "7127d743-873e-464b-927a-d23b9ad5b74a";
      cybrhuman = "14a67926-cff0-4542-a111-7f557d10cc67";
      stinl = "3a08be01-1e74-4d68-88d1-07d0eb23356f";
      Mirithing = "7b327f51-4f1b-4606-88c7-378eff1b92b1";
      _dextra = "4b7b4ee7-eb5b-48fd-88c3-1cc68f06acda";
      Soraryuu = "0d5ffe48-e64f-4d6d-9432-f374ea8ec10c";
      klarken1 = "d6967cb8-2bc6-4db7-a093-f0770cce47df";
    };
  };

  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];

  systemd.services."minecraft-backup" = {
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.mcrcon}/bin/mcrcon -p pvv "say Starting Backup" "save-off" "save-all"
      ${pkgs.rsync}/bin/rsync -aiz --delete ${config.pvv.minecraft-server-fabric.dataDir}/world /fast/backup # Where to put backup
      ${pkgs.mcrcon}/bin/mcrcon -p pvv "save-all" "say Completed Backup" "save-on" "save-all"
    '';
  };

  systemd.timers."minecraft-backup" = {
    wantedBy = ["timers.target"];
    timerConfig.OnCalendar = [ "hourly" ];
  };

}
