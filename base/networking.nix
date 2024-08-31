{ lib, values, ... }:
{
  networking.domain = "pvv.ntnu.no";
  networking.useDHCP = false;
  # networking.search = [ "pvv.ntnu.no" "pvv.org" ];
  # networking.nameservers = lib.mkDefault [ "129.241.0.200" "129.241.0.201" ];
  # networking.tempAddresses = lib.mkDefault "disabled";
  # networking.defaultGateway = values.hosts.gateway;

  systemd.network.enable = true;

  services.resolved = {
    enable = lib.mkDefault true;
    dnssec = "false"; # Supposdly this keeps breaking and the default is to allow downgrades anyways...
  };
}