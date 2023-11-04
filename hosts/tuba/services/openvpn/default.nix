{ lib, values, ... }:
{
  services.openvpn.servers."ov-tunnel" = {
    config = let
      conf = {
        # TODO: use aliases
        client = true;
        dev = "tap";
        proto = "udp";
        remote = "129.241.210.191 1194";

        resolv-retry = "infinite";
        nobind = true;

        # # TODO: set up
        ca = "";
        cert = "";
        key = "";
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
        else throw "Unknown value in tuba openvpn config, deading now\n${value}"
      ))
      (lib.mapAttrsToList (name: value: if value == true then name else "${name} ${value}"))
      (builtins.concatStringsSep "\n")
      (x: x + "\n\n")
    ];
  };
}
