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
    denominationConfig = ''
      ## Old denomination names cannot be used again
      # [COIN-${CURRENCY}-k1-1-0]

      ## NOK Denominations
      [coin-${CURRENCY}-nok-1-0]
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
      
      [coin-${CURRENCY}-nok-5-0]
      VALUE = ${CURRENCY}:5
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA

      [coin-${CURRENCY}-nok-10-0]
      VALUE = ${CURRENCY}:10
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
      
      [coin-${CURRENCY}-nok-20-0]
      VALUE = ${CURRENCY}:20
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
      
      [coin-${CURRENCY}-nok-50-0]
      VALUE = ${CURRENCY}:50
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
      
      [coin-${CURRENCY}-nok-100-0]
      VALUE = ${CURRENCY}:100
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
      
      [coin-${CURRENCY}-nok-200-0]
      VALUE = ${CURRENCY}:200
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
      
      [coin-${CURRENCY}-nok-500-0]
      VALUE = ${CURRENCY}:500
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA
      
      [coin-${CURRENCY}-nok-1000-0]
      VALUE = ${CURRENCY}:1000
      DURATION_WITHDRAW = 7 days
      DURATION_SPEND = 1 years
      DURATION_LEGAL = 3 years
      FEE_WITHDRAW = ${CURRENCY}:0
      FEE_DEPOSIT = ${CURRENCY}:0
      FEE_REFRESH = ${CURRENCY}:0
      FEE_REFUND = ${CURRENCY}:0
      RSA_KEYSIZE = 2048
      CIPHER = RSA

      ## PVV Special Prices
      # 2024 pizza egenandel
      [coin-${CURRENCY}-pvv-64-0]
      VALUE = ${CURRENCY}:64
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
      exchange-account-test = {
        PAYTO_URI = "payto://x-taler-bank/bank.kvernberg.pvv.ntnu.no/exchange?receiver-name=Exchange";
        ENABLE_DEBIT = "YES";
        ENABLE_CREDIT = "YES";
      };
      exchange-accountcredentials-test = {
        WIRE_GATEWAY_URL = "http://bank.kvernberg.pvv.ntnu.no/accounts/exchange/taler-wire-gateway/";
        WIRE_GATEWAY_AUTH_METHOD = "BASIC";
        USERNAME = "exchange";
        PASSWORD = "exchange";
      };
    };
  };

  services.nginx.virtualHosts."exchange.kvernberg.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/".proxyPass = "http://127.0.0.1:8081";
  };
}
