{ config, lib, values, ... }:
let
  cfg = config.services.cadvisor;
in
{
  services.cadvisor = {
    enable = lib.mkDefault true;
    listenAddress = "127.0.0.1";
    port = 9338;
    extraOptions = [
      "-housekeeping_interval=15s"
      "-store_container_labels=false"
      "-raw_cgroup_prefix_whitelist=/system.slice/,/machine.slice/"
    ];
  };

  systemd.services.cadvisor = lib.mkIf cfg.enable {
    serviceConfig = {
      Slice = "system-monitoring.slice";
      ManagedOOMPreference = "avoid";
      MemoryLow = "64M";
      MemoryHigh = "192M";
      MemoryMax = "256M";
    };
  };

  services.nginx = lib.mkIf cfg.enable {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      enableACME = true;

      locations."/prometheus-cadvisor/metrics" = {
        proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}/metrics";

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
