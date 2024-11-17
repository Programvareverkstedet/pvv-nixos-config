{ config, lib, pkgs, ... }:
let
  cfg = config.services.libeufin.bank;
  tcfg = config.services.taler;
  inherit (tcfg.settings.taler) CURRENCY;
in {
  services.libeufin.bank = {
    enable = true;
    debug = true;
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
        X_TALER_BANK_PAYTO_HOSTNAME = "bank.kvernberg.pvv.ntnu.no";
        BASE_URL = "bank.kvernberg.pvv.ntnu.no";

        ALLOW_REGISTRATION = "yes";

        REGISTRATION_BONUS_ENABLED = "yes";
        REGISTRATION_BONUS = "${CURRENCY}:500";

        DEFAULT_DEBT_LIMIT = "${CURRENCY}:0";

        ALLOW_CONVERSION = "no";
        ALLOW_EDIT_CASHOUT_PAYTO_URI = "yes";

        SUGGESTED_WITHDRAWAL_EXCHANGE = "https://exchange.kvernberg.pvv.ntnu.no/";

        inherit CURRENCY;
      };
    };
  };

  services.nginx.virtualHosts."bank.kvernberg.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/".proxyPass = "http://127.0.0.1:8082";
  };
  
}
