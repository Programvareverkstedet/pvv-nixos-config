{ config, values, ... }:
{
  services.nginx = {
    enable = true;
    enableReload = true;
    defaultListenAddresses = [
      values.hosts.ildkule.ipv4
      "[${values.hosts.ildkule.ipv6}]"

      "127.0.0.1"
      "127.0.0.2"
      "[::1]"
    ];
  };
}
