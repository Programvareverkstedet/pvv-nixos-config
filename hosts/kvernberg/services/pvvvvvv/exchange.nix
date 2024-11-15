{ config, lib, fp, pkgs, ... }:
let
  cfg = config.services.taler;
  inherit (cfg.settings.taler) CURRENCY;
in {
  sops.secrets.exchange-offline-master = {
    format = "binary";
    sopsFile = fp /secrets/kvernberg/exhange-offline-master.priv;
  };

  services.taler.exchange = {
    enable = true;
    debug = true;
    openFirewall = true;
    denominationConfig = ''
      [COIN-${CURRENCY}-k1-1-0]
      VALUE = ${CURRENCY}:1
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
    '';
    settings = {
      exchange = {
        MASTER_PUBLIC_KEY = "J331T37C8E58P9CVE686P1JFH11DWSRJ3RE4GVDTXKES9M24ERZG";
        BASE_URL = "http://kvernberg.pvv.ntnu.no:8081/";
      };
      exchange-offline = {
        MASTER_PRIV_FILE = config.sops.secrets.exchange-offline-master.path;
      };
    };
  };
}
