{
  config,
  lib,
  values,
  ...
}:
let
  cfg = config.services.journald.remote;
  domainName = "journald.pvv.ntnu.no";
in
{
  security.acme.certs.${domainName} = {
    webroot = "/var/lib/acme/acme-challenge/";
    group = config.services.nginx.group;
  };

  services.nginx = {
    enable = true;
    virtualHosts.${domainName} = {
      forceSSL = true;
      useACMEHost = "${domainName}";
      locations."/.well-known/".root = "/var/lib/acme/acme-challenge/";
    };
  };

  services.journald.upload.enable = lib.mkForce false;

  services.journald.remote = {
    enable = true;
    settings.Remote =
      let
        inherit (config.security.acme.certs.${domainName}) directory;
      in
      {
        ServerKeyFile = "/run/credentials/systemd-journal-remote.service/key.pem";
        ServerCertificateFile = "/run/credentials/systemd-journal-remote.service/cert.pem";
        TrustedCertificateFile = "-";
      };
  };

  systemd.sockets."systemd-journal-remote" = {
    socketConfig = {
      IPAddressDeny = "any";
      IPAddressAllow = [
        "127.0.0.1"
        "::1"
        values.ipv4-space
        values.ipv6-space
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ cfg.port ];

  systemd.services."systemd-journal-remote" = {
    serviceConfig = {
      LoadCredential =
        let
          inherit (config.security.acme.certs.${domainName}) directory;
        in
        [
          "key.pem:${directory}/key.pem"
          "cert.pem:${directory}/cert.pem"
        ];
    };
  };
}
