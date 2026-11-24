{ config, lib, ... }:
let
  cfg = config.services.gatus;
  cfgTuwunel = config.services.matrix-tuwunel;
in
{
  imports = [
    ./minecraft-checker.nix
    ./postgres-checker.nix
    ./mariadb-checker.nix
  ];

  sops.secrets."keys/tuwunel/elgato/access_token" = {
    restartUnits = [ "gatus.service" ];
  };

  sops.templates."gatus.env" = {
    restartUnits = [ "gatus.service" ];
    content = ''
      MATRIX_ACCESS_TOKEN=${config.sops.placeholder."keys/tuwunel/elgato/access_token"}
    '';
  };

  services.gatus = {
    enable = true;
    environmentFile = config.sops.templates."gatus.env".path;

    settings = {
      metrics = true;

      web = {
        address = "127.0.0.1";
        port = 19283;
      };

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      alerting.matrix = {
        server-url = "http://127.0.0.1:${toString (lib.head cfgTuwunel.settings.global.port)}";
        access-token = "$MATRIX_ACCESS_TOKEN";
        # #grafana:alerts.pvv.ntnu.no
        internal-room-id = "!hrLcMhBaGzNkiRSXKKxrugXiluXN8044FjIFwjZqFD4";
        default-alert.send-on-resolved = true;
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
        # TODO: set up bikkje
        # (mkMachine "bikkje")
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
        (mkMachine "hildring")
        (mkMachine "homeassistant")
        (mkMachine "innovation")
        (mkMachine "isvegg")
        (mkMachine "knutsen")
        (mkMachine "ludvigsen" // {
          url = "icmp://ludvigsen-tap.pvv.ntnu.no";
        })
        (mkMachine "microbel")
        (mkMachine "mirage")
        (mkMachine "sunset")
        (mkMachine "orchid")
        (mkMachine "principal")
        (mkMachine "sleipner")
        (mkMachine "smask")
        # (mkMachine "tom")
        (mkMachine "wegonke")
      ]) ++ [
        (mkWebsite "Alps" "https://alps.pvv.ntnu.no" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Bluemap" "https://minecraft.pvv.ntnu.no" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Element Web" "https://chat.pvv.ntnu.no" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Gitea" "https://git.pvv.ntnu.no/api/healthz" // {
          alerts = [{ type = "matrix"; }];
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
        (mkWebsite "Grzegorz - Brzeczyszczykiewicz" "https://brzeczyszczykiewicz.pvv.ntnu.no/health" // {
          conditions = [
            "[STATUS] == 200"
            "[BODY].status == ok"
          ];
        })
        (mkWebsite "Grzegorz - Georg" "https://georg.pvv.ntnu.no/health" // {
          conditions = [
            "[STATUS] == 200"
            "[BODY].status == ok"
          ];
        })
        (mkWebsite "Home Assistant" "https://homeassistant.pvv.ntnu.no:8123/auth/providers" // {
          conditions = [
            "[STATUS] == 200"
            "len([BODY].providers) > 0"
          ];
        })
        (mkWebsite "IDP" "https://idp.pvv.ntnu.no" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Mailing Lists" "http://list.pvv.ntnu.no")
        (mkWebsite "Mapcrafter" "http://isvegg.pvv.ntnu.no/kart")
        (mkWebsite "PVV-Nettsiden" "https://www.pvv.ntnu.no" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Roundcube" "https://webmail.pvv.ntnu.no/roundcube" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Scrutiny" "https://scrutiny.pvv.ntnu.no/api/health" // {
          conditions = [
            "[STATUS] == 200"
            "[BODY].success == true"
          ];
        })
        (mkWebsite "Snappymail" "http://snappymail.pvv.ntnu.no")
        (mkWebsite "Userweb - Temmie" "https://temmie.pvv.ntnu.no/~oysteikt")
        # (mkWebsite "Userweb - Tom" "https://www.pvv.ntnu.no/~oysteikt")
        (mkWebsite "Vaultwarden" "https://pw.pvv.ntnu.no/alive" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkWebsite "Wiki" "https://wiki.pvv.ntnu.no/w/api.php?action=query&format=json")

        # ----------------------------------------------------------------------------- #

        (mkService "Email (IMAP)" "tls://mail.pvv.ntnu.no:993" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkService "Email (POP3)" "tls://mail.pvv.ntnu.no:995" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkService "Email (SMTP)" "starttls://mail.pvv.ntnu.no:587" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkService "Gitea SSH" "ssh://git.pvv.ntnu.no:2222" // {
          alerts = [{ type = "matrix"; }];
        })
        (mkService "Loki" "https://loki.pvv.ntnu.no/ready" // {
          alerts = [{ type = "matrix"; }];
          conditions = [
            "[STATUS] == 200"
          ];
        })
        (mkService "MariaDB" "http://localhost:1339" // {
          alerts = [{ type = "matrix"; }];
          conditions = [
            "[STATUS] == 200"
            "[BODY].ok == true"
          ];
        })
        (mkService "Matrix Mjolnir" "https://matrix.pvv.ntnu.no/mjolnir/healthz" // {
          conditions = [
            "[STATUS] == 200"
          ];
        })
        (mkService "Matrix OOYE" "https://ooye.pvv.ntnu.no/api/stats" // {
          alerts = [{ type = "matrix"; }];
          conditions = [
            "[STATUS] == 200"
            "[BODY].guilds > 0"
          ];
        })
        (mkService "Matrix Synapse" "https://matrix.pvv.ntnu.no/_matrix/client/versions" // {
          alerts = [{ type = "matrix"; }];
          method = "GET";
          conditions = [
            "[STATUS] == 200"
          ];
        })
        (mkService "Tuwunel" "https://alerts.pvv.ntnu.no/_matrix/client/versions" // {
          method = "GET";
          conditions = [
            "[STATUS] == 200"
          ];
        })
        (mkService "Minecraft" "http://localhost:1337" // {
          alerts = [{ type = "matrix"; }];
          conditions = [
            "[STATUS] == 200"
            "[BODY].ok == true"
          ];
        })
        (mkService "PostgreSQL" "http://localhost:1338" // {
          alerts = [{ type = "matrix"; }];
          conditions = [
            "[STATUS] == 200"
            "[BODY].ok == true"
          ];
        })
        (mkService "QoTD" "tcp://bekkalokk.pvv.ntnu.no:17")
      ];
    };
  };

  systemd.services.gatus.environment.GATUS_LOG_LEVEL = "WARN";

  services.nginx.upstreams.gatus = lib.mkIf cfg.enable {
    servers."${cfg.settings.web.address}:${toString cfg.settings.web.port}" = { };
  };

  services.nginx.virtualHosts."status.pvv.ntnu.no" = lib.mkIf cfg.enable {
    enableACME = true;
    locations."/".proxyPass = "http://gatus";
    locations."= /metrics".return = "404";
  };

  services.prometheus.scrapeConfigs = lib.mkIf cfg.enable [{
    job_name = "gatus";
    static_configs = [{
      targets = [ "${cfg.settings.web.address}:${toString cfg.settings.web.port}" ];
    }];
  }];

  services.fluent-bit.settings = {
    parsers = [
      {
        name = "gatus_watchdog";
        format = "regex";
        regex = ''^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} \[watchdog\.executeEndpoint\] Monitored group=(?<group>[^;]*); endpoint=(?<endpoint>[^;]*); key=(?<key>[^;]*); success=(?<success>true|false); errors=(?<errors>\d+); duration=(?<duration>\S+)$'';
      }
    ];

    pipeline.filters = lib.mkAfter [
      {
        name = "parser";
        match = "journal.gatus.service";
        key_name = "message";
        parser = "gatus_watchdog";
        reserve_data = true;
      }
    ];
  };
}
