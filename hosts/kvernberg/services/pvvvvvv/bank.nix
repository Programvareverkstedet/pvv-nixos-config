{ config, lib, pkgs, ... }:
let
  cfg = config.services.libeufin.bank;
  tcfg = config.services.taler;
  inherit (tcfg.settings.taler) CURRENCY;
in {
  services.libeufin.bank = {
    enable = true;
    debug = true;
    openFirewall = true;
    createLocalDatabase = true;
    initialAccounts = [
      { username = "exchange";
        password = "exchange";
        name = "Exchange";
      }
    ];
    settings = {
      libeufin-bank = {
        WIRE_TYPE = "x-taler-bank";
        X_TALER_BANK_PAYTO_HOSTNAME = "kvernberg.pvv.ntnu.no:8082";
        BASE_URL = "kvernberg.pvv.ntnu.no:8082";

        ALLOW_REGISTRATION = "yes";

        REGISTRATION_BONUS_ENABLED = "yes";
        REGISTRATION_BONUS = "${CURRENCY}:100";

        DEFAULT_DEBT_LIMIT = "${CURRENCY}:500";

        ALLOW_CONVERSION = "no";
        ALLOW_EDIT_CASHOUT_PAYTO_URI = "yes";

        SUGGESTED_WITHDRAWAL_EXCHANGE = "http://kvernberg.pvv.ntnu.no:8081/";

        inherit CURRENCY;
      };
    };
  };
}
