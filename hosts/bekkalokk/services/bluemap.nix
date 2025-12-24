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
        settings = {
          world = vanillaSurvival;
          dimension = "minecraft:overworld";
          sorting = 0;
          start-pos = {
            x = 0;
            y = 0;
          };
          ambient-light = 0.1;
          cave-detection-ocean-floor = -5;
          marker-sets = {
            _includes = [ (format.lib.mkInclude "${bluemap-export}/overworld.hocon") ];
          };
        };
      };
      "underverden" = {
        settings = {
          world = vanillaSurvival;
          dimension = "minecraft:the_nether";
          sorting = 100;
          start-pos = {
            x = 0;
            y = 0;
          };
          sky-color = "#290000";
          void-color = "#150000";
          ambient-light = 0.6;
          world-sky-light = 0;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
          cave-detection-uses-block-light = true;
          max-y = 90;
          marker-sets = {
            _includes = [ (format.lib.mkInclude "${bluemap-export}/nether.hocon") ];
          };
        };
      };
      "enden" = {
        settings = {
          world = vanillaSurvival;
          dimension = "minecraft:the_end";
          sorting = 200;
          start-pos = {
            x = 0;
            y = 0;
          };
          sky-color = "#080010";
          void-color = "#080010";
          ambient-light = 0.6;
          world-sky-light = 0;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
          marker-sets = {
            _includes = [ (format.lib.mkInclude "${bluemap-export}/the-end.hocon") ];
          };
        };
      };
    };
  };

  services.nginx.virtualHosts."minecraft.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
  };

  systemd.services."render-bluemap-maps" = {
    preStart = ''
      mkdir -p /var/lib/bluemap/world
      ${pkgs.rsync}/bin/rsync \
        -e "${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=$CREDENTIALS_DIRECTORY/ssh-known-hosts -i $CREDENTIALS_DIRECTORY/sshkey" \
        -avz --no-owner --no-group \
        root@innovation.pvv.ntnu.no:/ \
        ${vanillaSurvival}
    '';
    serviceConfig = {
      LoadCredential = [
        "sshkey:${config.sops.secrets."bluemap/ssh-key".path}"
        "ssh-known-hosts:${config.sops.secrets."bluemap/ssh-known-hosts".path}"
      ];
    };
  };
}
