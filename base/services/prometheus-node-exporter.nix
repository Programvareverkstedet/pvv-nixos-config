{
  config,
  lib,
  values,
  ...
}:
let
  cfg = config.services.prometheus.exporters.node;
in
{
  services.prometheus.exporters.node = {
    enable = lib.mkDefault true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  systemd.services.prometheus-node-exporter.serviceConfig = lib.mkIf cfg.enable {
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
