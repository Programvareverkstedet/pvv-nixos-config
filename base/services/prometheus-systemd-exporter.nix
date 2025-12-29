{ config, lib, values, ... }:
let
  cfg = config.services.prometheus.exporters.systemd;
in
{
  services.prometheus.exporters.systemd = {
    enable = lib.mkDefault true;
    port = 9101;
    extraFlags = [
      "--systemd.collector.enable-restart-count"
      "--systemd.collector.enable-ip-accounting"
    ];
  };

  systemd.services.prometheus-systemd-exporter.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      "127.0.0.1"
      "::1"
      values.hosts.ildkule.ipv4
      values.hosts.ildkule.ipv6
    ];
  };

  networking.firewall.allowedTCPPorts = lib.mkIf cfg.enable [ cfg.port ];
}
