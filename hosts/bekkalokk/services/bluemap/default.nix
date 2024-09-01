{ config, lib, pkgs, inputs, ... }:
let
  vanillaSurvival = "/var/lib/bluemap/vanilla_survival_world";
in {
  imports = [
    ./module.nix # From danio, pending upstreaming
  ];

  disabledModules = [ "services/web-servers/bluemap.nix" ];

  sops.secrets."bluemap/ssh-key" = { };
  sops.secrets."bluemap/ssh-known-hosts" = { };

  services.bluemap = {
    enable = true;
    eula = true;
    onCalendar = "*-*-* 05:45:00"; # a little over an hour after auto-upgrade

    host = "minecraft.pvv.ntnu.no";

    maps = {
      "verden" = {
        settings = {
          world = vanillaSurvival;
          sorting = 0;
          ambient-light = 0.1;
          cave-detection-ocean-floor = -5;
          marker-sets = inputs.minecraft-data.map-markers.vanillaSurvival.verden;
        };
      };
      "underverden" = {
        settings = {
          world = "${vanillaSurvival}/DIM-1";
          sorting = 100;
          sky-color = "#290000";
          void-color = "#150000";
          ambient-light = 0.6;
          world-sky-light = 0;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
          cave-detection-uses-block-light = true;
          max-y = 90;
          marker-sets = inputs.minecraft-data.map-markers.vanillaSurvival.underverden;
        };
      };
      "enden" = {
        settings = {
          world = "${vanillaSurvival}/DIM1";
          sorting = 200;
          sky-color = "#080010";
          void-color = "#080010";
          ambient-light = 0.6;
          world-sky-light = 0;
          remove-caves-below-y = -10000;
          cave-detection-ocean-floor = -5;
        };
      };
    };
  };

  services.nginx.virtualHosts."minecraft.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
  };

  # TODO: render somewhere else lmao
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
