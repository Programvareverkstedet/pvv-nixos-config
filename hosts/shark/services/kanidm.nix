{ config, pkgs, lib, ... }:
let
  cfg = config.services.kanidm;
  domain = "idmtest.pvv.ntnu.no";
  bindaddr_web = "127.0.0.1:8300"; #
  bindaddr_ldaps = "0.0.0.0:636";
in {
  # Kanidm - Identity management / auth provider
  services.kanidm = {
    enableServer = true;

    serverSettings = let
      credsDir = "/run/credentials/kanidm.service";
    in {
      inherit domain;
      ldapbindaddress = bindaddr_ldaps;
      bindaddress = bindaddr_web;
      origin = "https://${domain}";

      tls_chain = "${credsDir}/fullchain.pem";
      tls_key = "${credsDir}/key.pem";
    };
  };

  systemd.services.kanidm = {
    requires = [ "acme-finished-${domain}.target" ];
    serviceConfig.LoadCredential = let
      certDir = config.security.acme.certs.${domain}.directory;
    in [
      "fullchain.pem:${certDir}/fullchain.pem"
      "key.pem:${certDir}/key.pem"
    ];
  };

  services.nginx.virtualHosts."${cfg.serverSettings.domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "https://${cfg.serverSettings.bindaddress}";
  };

  environment = {
    systemPackages = [ pkgs.kanidm ]; # CLI tool
    etc."kanidm/config".text = ''
      uri="${cfg.serverSettings.origin}"
    '';
  };
 }
