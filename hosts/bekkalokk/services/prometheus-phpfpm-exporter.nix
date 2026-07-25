{ config, lib, values, ... }:
let
  cfg = config.services.prometheus.exporters.php-fpm;
  pools = [
    "idp"
    "mediawiki"
    "pvv-nettsiden"
    "roundcube"
    "snappymail"
  ];
in
{
  services.phpfpm.pools = lib.genAttrs pools (_: {
    settings."pm.status_path" = "/status";
  });

  services.prometheus.exporters.php-fpm = {
    enable = true;
    listenAddress = "127.0.0.1";
    extraFlags = [
      "--phpfpm.scrape-uri=${lib.concatMapStringsSep "," (name: "unix://${config.services.phpfpm.pools.${name}.socket};/status") pools}"
    ];
  };

  systemd.services.prometheus-php-fpm-exporter.serviceConfig = {
    Slice = "system-monitoring.slice";
    SupplementaryGroups = [ config.services.nginx.group ];
    RestrictAddressFamilies = lib.mkForce [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
  };

  services.nginx = lib.mkIf cfg.enable {
    virtualHosts."www.pvv.ntnu.no" = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-php-fpm-exporter/metrics" = {
        proxyPass = "http://localhost:${toString cfg.port}/metrics";

        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      };
    };
  };
}
