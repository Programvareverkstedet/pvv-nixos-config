{ config, values, ... }:
{
  services.nginx = {
    enable = true;
    enableReload = true;
    defaultListenAddresses = [
      values.hosts.bicep.ipv4
      "[${values.hosts.bicep.ipv6}]"

      "127.0.0.1"
      "127.0.0.2"
      "[::1]"
    ];
  };
}
