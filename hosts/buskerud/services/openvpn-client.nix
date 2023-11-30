{ lib, values, ... }:
{
  services.openvpn.servers."ov-tunnel" = {
    config = let
      conf = {
        # TODO: use aliases
        client = true;
        dev = "tap";
        proto = "udp";
        #remote = "129.241.210.253 1194";
        remote = "129.241.210.191 1194";

        resolv-retry = "infinite";
        nobind = true;

        ca = "/etc/openvpn/ca.pem";
        cert = "/etc/openvpn/crt.pem";
        key = "/etc/openvpn/key.pem";
        remote-cert-tls = "server";
        cipher = "none";

        user = "nobody";
        group = "nobody";

        status = "/var/log/openvpn-status.log";

        persist-key = true;
        persist-tun = true;

        verb = 5;

        # script-security = 2;
        # up = "systemctl restart rwhod";
      };
    in lib.pipe conf [
      (lib.filterAttrs (_: value: !(builtins.isNull value || value == false)))
      (builtins.mapAttrs (_: value:
        if builtins.isList value then builtins.concatStringsSep " " (map toString value)
        else if value == true then value
        else if builtins.any (f: f value) [
          builtins.isString
          builtins.isInt
          builtins.isFloat
          lib.isPath
          lib.isDerivation
        ] then toString value
        else throw "Unknown value in buskerud openvpn config, deading now\n${value}"
      ))
      (lib.mapAttrsToList (name: value: if value == true then name else "${name} ${value}"))
      (builtins.concatStringsSep "\n")
      (x: x + "\n\n")
    ];
  };

  systemd.network.networks."enp14s0f1" = {
    matchConfig.Name = "enp14s0f1";
    networkConfig = {
      DefaultRouteOnDevice = true;
    };
    routes = [
      { routeConfig = {
          Type = "unicast";
          Destination = values.hosts.knutsen.ipv4 + "/32";
          Metric = 50;
        };
      }
    ];
  };

  systemd.network.netdevs."br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
  };

  systemd.network.networks."br0" = {
    matchConfig.Name = "br0";
    routes = [
      { routeConfig = {
          Type = "unicast";
          Destination = values.ipv4-space;
          Metric = 100;
        };
      }
    ];
  };

  systemd.network.networks."enp3s0f0" = {
    matchConfig.Name = "enp3s0f0";
    networkConfig.DefaultRouteOnDevice = false;
  };

  systemd.network.networks."enp3s0f1" = {
    matchConfig.Name = "enp3s0f1";
    bridge = [ "br0" ];
  };

  systemd.network.networks."tap0" = {
    matchConfig.Name = "tap0";
    bridge = [ "br0" ];
  };

  #networking.nat = {
  #  enable = true;
  #  externalInterface = "enp14s0f1";
  #  internalInterfaces  = [ "tun" ];
  #};
}
