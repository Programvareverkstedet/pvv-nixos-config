{ config, lib, ... }:

{
  sops.secrets."matrix/mjolnir/access_token" = {
    sopsFile = ../../../../secrets/bicep/matrix.yaml;
    key = "mjolnir/access_token";
    owner = config.users.users.mjolnir.name;
    group = config.users.users.mjolnir.group;
  };

  services.mjolnir = {
    enable = true;
    pantalaimon.enable = false;
    homeserverUrl = http://127.0.0.1:8008;
    accessTokenFile = config.sops.secrets."matrix/mjolnir/access_token".path;
    managementRoom = "!gsdeCoWjvYRBrzuiRq:pvv.ntnu.no";
    protectedRooms = map (a: "https://matrix.to/#/${a}") [
      "#pvv:pvv.ntnu.no"
      "#stand:pvv.ntnu.no"
      "#music:pvv.ntnu.no"
      "#arts-and-crafts:pvv.ntnu.no"
      "#programming:pvv.ntnu.no"
      "#talks-and-texts:pvv.ntnu.no"
      "#job-offers:pvv.ntnu.no"
      "#vaffling:pvv.ntnu.no"
      "#pvv-fadder:pvv.ntnu.no"
      "#offsite:pvv.ntnu.no"
      "#help:pvv.ntnu.no"
      "#garniske-algoritmer:pvv.ntnu.no"
      "#bouldering:pvv.ntnu.no"
      "#filmclub:pvv.ntnu.no"
      "#video-games:pvv.ntnu.no"
      "#board-games:pvv.ntnu.no"
      "#tabletop-rpgs:pvv.ntnu.no"
      "#anime:pvv.ntnu.no"
      "#general:pvv.ntnu.no"
      "#announcements:pvv.ntnu.no"
      "#memes:pvv.ntnu.no"

      "#drift:pvv.ntnu.no"
      "#notifikasjoner:pvv.ntnu.no"
      "#forespoersler:pvv.ntnu.no"
      "#krisekanalen:pvv.ntnu.no"

      "#styret:pvv.ntnu.no"
    ];

    settings = {
      admin.enableMakeRoomAdminCommand = true;
    };

    # Module wants it even when not using pantalaimon
    # TODO: Fix upstream module in nixpkgs
    pantalaimon.username = "bot_admin";
  };
}
