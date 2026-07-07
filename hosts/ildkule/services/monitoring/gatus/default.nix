{ config, lib, ... }:
let
  cfg = config.services.gatus;
in
{
  imports = [
    ./minecraft-checker.nix
  ];

  services.gatus = {
    enable = true;

    settings = {
      web = {
        address = "127.0.0.1";
        port = 19283;
      };

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      ui = {
        title = "PVV Nede!?";
        header = "😭😭😭";
        dashboard-heading = "PVV Nede!?";
        dashboard-subheading = "Kan noen ringe drift?";
      };

      endpoints = let
        mkMachine = name: {
          inherit name;
          group = "Machines";
          url = "icmp://${name}.pvv.ntnu.no";
          conditions = [
            "[CONNECTED] == true"
          ];
        };

        mkWebsite = name: url: {
          inherit name url;
          group = "Websites";
          method = "GET";
          conditions = [
            "[STATUS] == 200"
          ];
        };

        mkService = name: url: {
          inherit name url;
          group = "Services";
          conditions = [
            "[CONNECTED] == true"
          ];
        };
      in (lib.sortOn (m: m.name) [
        (mkMachine "ambidextrous")
        (mkMachine "bekkalokk")
        (mkMachine "bicep")
        (mkMachine "bikkje")
        (mkMachine "brzeczyszczykiewicz")
        (mkMachine "georg")
        (mkMachine "gluttony")
        (mkMachine "ildkule")
        (mkMachine "kana")
        (mkMachine "kommode")
        (mkMachine "lupine-1")
        (mkMachine "lupine-2")
        (mkMachine "lupine-3")
        (mkMachine "lupine-4")
        (mkMachine "lupine-5")
        (mkMachine "skrot")
        (mkMachine "temmie")
        (mkMachine "wenche")

        (mkMachine "balduzius")
        (mkMachine "blossom")
        (mkMachine "bubbles")
        (mkMachine "buskerud")
        (mkMachine "buttercup")
        (mkMachine "demiurgen")
        (mkMachine "drolsum")
        (mkMachine "hildring")
        (mkMachine "innovation")
        (mkMachine "isvegg")
        (mkMachine "knutsen")
        (mkMachine "ludvigsen" // {
          url = "icmp://ludvigsen-tap.pvv.ntnu.no";
        })
        (mkMachine "microbel")
        (mkMachine "mirage")
        (mkMachine "orchid")
        (mkMachine "principal")
        (mkMachine "sleipner")
        (mkMachine "smask")
        (mkMachine "tom")
        (mkMachine "wegonke")
      ]) ++ [
        (mkWebsite "Bluemap" "https://minecraft.pvv.ntnu.no")
        (mkWebsite "Element Web" "https://chat.pvv.ntnu.no")
        (mkWebsite "Gitea" "https://git.pvv.ntnu.no/api/healthz" // {
          conditions = [
            "[STATUS] == 200"
            "[BODY].status == pass"
          ];
        })
        (mkWebsite "Grafana" "https://grafana.pvv.ntnu.no/api/health" // {
          conditions = [
            "[STATUS] == 200"
            "[BODY].database == ok"
          ];
        })
        (mkWebsite "Grzegorz - Brzeczyszczykiewicz" "https://brzeczyszczykiewicz.pvv.ntnu.no")
        (mkWebsite "Grzegorz - Georg" "https://georg.pvv.ntnu.no")
        (mkWebsite "IDP" "https://idp.pvv.ntnu.no")
        (mkWebsite "Mailing Lists" "http://list.pvv.ntnu.no")
        (mkWebsite "Mapcrafter" "http://isvegg.pvv.ntnu.no/kart")
        (mkWebsite "PVV-Nettsiden" "https://www.pvv.ntnu.no")
        (mkWebsite "Roundcube" "https://webmail.pvv.ntnu.no/roundcube")
        (mkWebsite "Scrutiny" "https://scrutiny.pvv.ntnu.no")
        (mkWebsite "Snappymail" "http://snappymail.pvv.ntnu.no")
        (mkWebsite "Userweb - Temmie" "https://temmie.pvv.ntnu.no/~oysteikt")
        (mkWebsite "Userweb - Tom" "https://www.pvv.ntnu.no/~oysteikt")
        (mkWebsite "Vaultwarden" "https://pw.pvv.ntnu.no/alive")
        (mkWebsite "Wiki" "https://wiki.pvv.ntnu.no/w/api.php?action=query&format=json")

        (mkService "Gitea SSH" "ssh://git.pvv.ntnu.no:2222")
        (mkService "QoTD" "tcp://bekkalokk.pvv.ntnu.no:17")
        (mkService "Minecraft" "http://localhost:1337" // {
          conditions = [
            "[STATUS] == 200"
            "[BODY].ok == true"
          ];
        })
        (mkService "Email (SMTP)" "starttls://mail.pvv.ntnu.no:587")
        (mkService "Email (POP3)" "tls://mail.pvv.ntnu.no:995")
        (mkService "Email (IMAP)" "tls://mail.pvv.ntnu.no:993")
        (mkService "Matrix Synapse" "https://matrix.pvv.ntnu.no/_matrix/client/versions" // {
          method = "GET";
          conditions = [
            "[STATUS] == 200"
          ];
        })
      ];
    };
  };

  services.nginx.virtualHosts."status.pvv.ntnu.no" = lib.mkIf cfg.enable {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/".proxyPass = "http://localhost:${toString cfg.settings.web.port}";
  };
}
