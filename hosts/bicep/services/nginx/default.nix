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

    appendConfig = ''
      worker_processes 8;
      worker_rlimit_nofile 8192;
    '';

    eventsConfig = ''
      multi_accept on;
      worker_connections 4096;
    '';
  };
}
