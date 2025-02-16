{ config, lib, pkgs, ... }:
let
  cfg = config.services.taler;
in
{
  imports = [
    ./exchange.nix
    ./bank.nix
  ];

  services.taler = {
    settings = {
      taler.CURRENCY = "SCHPENN";
      taler.CURRENCY_ROUND_UNIT = "${cfg.settings.taler.CURRENCY}:1";
    };
  };
}
