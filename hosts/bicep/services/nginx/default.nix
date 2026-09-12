{ config, values, pkgs, ... }:
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
    virtualHosts."matrix.pvv.ntnu.no" = {
      root = pkgs.writeTextDir "index.html" (builtins.readFile ./index.html);
    };
  };
}
