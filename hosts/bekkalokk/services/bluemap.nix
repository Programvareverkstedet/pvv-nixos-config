{ config, lib, pkgs, inputs, ... }:
let
  vanillaSurvival = "/var/lib/bluemap/vanilla_survival_world";
  format = pkgs.formats.hocon { };
in {
  # NOTE: our versino of the module gets added in flake.nix
  disabledModules = [ "services/web-apps/bluemap.nix" ];

  sops.secrets."bluemap/ssh-key" = { };
  sops.secrets."bluemap/ssh-known-hosts" = { };

  services.bluemap = {
    enable = true;

    eula = true;
    onCalendar = "*-*-* 05:45:00"; # a little over an hour after auto-upgrade

    host = "minecraft.pvv.ntnu.no";

    maps = let
      inherit (inputs.minecraft-kartverket.packages.${pkgs.stdenv.hostPlatform.system}) bluemap-export;
    in {
      "verden" = {
        extraHoconMarkersFile = "${bluemap-export}/overworld.hocon";
        settings = {
          world = vanillaSurvival;
          dimension = "minecraft:overworld";
          name = "Verden";
          sorting = 0;
          start-pos = {
            x = 0;
            z = 0;
          };
          ambient-light = 0.1;
          cave-detection-ocean-floor = -5;
        };
      };
      "underverden" = {
        extraHoconMarkersFile = "${bluemap-export}/nether.hocon";
        settings = {
          world = vanillaSurvival;
          dimension = "minecraft:the_nether";
          name = "Underverden";
          sorting = 100;
          start-pos = {
            x = 0;
            z = 0;
          };
          sky-color = "#290000";
          void-color = "#150000";
          sky-light = 1;
          ambient-light = 0.6;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
          cave-detection-uses-block-light = true;
          render-mask = [{
            max-y = 90;
          }];
        };
      };
      "enden" = {
        extraHoconMarkersFile = "${bluemap-export}/the-end.hocon";
        settings = {
          world = vanillaSurvival;
          dimension = "minecraft:the_end";
          name = "Enden";
          sorting = 200;
          start-pos = {
            x = 0;
            z = 0;
          };
          sky-color = "#080010";
          void-color = "#080010";
          sky-light = 1;
          ambient-light = 0.6;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
        };
      };
    };
  };

  systemd.services."render-bluemap-maps" = {
    serviceConfig = {
      StateDirectory = [ "bluemap/world" ];
      ExecStartPre = let
        rsyncArgs = lib.cli.toCommandLineShellGNU { } {
          archive = true;
          compress = true;
          verbose = true;
          no-owner = true;
          no-group = true;
          rsh = "${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=%d/ssh-known-hosts -i %d/sshkey";
        };
      in "${lib.getExe pkgs.rsync} ${rsyncArgs} root@innovation.pvv.ntnu.no:/ ${vanillaSurvival}";
      LoadCredential = [
        "sshkey:${config.sops.secrets."bluemap/ssh-key".path}"
        "ssh-known-hosts:${config.sops.secrets."bluemap/ssh-known-hosts".path}"
      ];
    };
  };

  services.nginx.virtualHosts."minecraft.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    http3 = true;
    quic = true;
    http3_hq = true;
    extraConfig = ''
      # Enabling QUIC 0-RTT
      ssl_early_data on;

      quic_gso on;
      quic_retry on;
      add_header Alt-Svc 'h3=":$server_port"; ma=86400';
    '';
  };

  networking.firewall.allowedUDPPorts = [ 443 ];
}
