{ pkgs, lib, values, ... }:
{
  services.openvpn.servers."ov-tunnel" = {
    config = let
      conf = {
        # TODO: use aliases
        local = "129.241.210.191";
        port = 1194;
        proto = "udp";
        dev = "tap";

        # TODO: set up
        ca = "";
        cert = "";
        key = "";
        dh = "";

        # Maintain a record of client <-> virtual IP address
        # associations in this file.  If OpenVPN goes down or
        # is restarted, reconnecting clients can be assigned
        # the same virtual IP address from the pool that was
        # previously assigned.
        ifconfig-pool-persist = ./ipp.txt;

        server-bridge = builtins.concatStringsSep " " [
          "129.241.210.129"
          "255.255.255.128"
          "129.241.210.253"
          "129.241.210.254"
        ];

        keepalive = "10 120";
        cipher = "none";

        user = "nobody";
        group = "nobody";

        status = "/var/log/openvpn-status.log";

        client-config-dir = pkgs.writeTextDir "tuba" ''
          # Sett IP-adr. for tap0 til tubas PVV-adr.
          ifconfig-push ${values.services.tuba-tap} 255.255.255.128
          # Hvordan skal man faa dette til aa funke, tro?
          #ifconfig-ipv6-push 2001:700:300:1900::xxx/64
          
          # La tuba bruke std. PVV-gateway til all trafikk (unntatt
          # VPN-tunnellen).
          push "redirect-gateway"
        '';

        persist-key = true;
        persist-tun = true;

        verb = 5;

        explicit-exit-notify = 1;
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
        else throw "Unknown value in grevling openvpn config, deading now\n${value}"
      ))
      (lib.mapAttrsToList (name: value: if value == true then name else "${name} ${value}"))
      (builtins.concatStringsSep "\n")
      (x: x + "\n\n")
    ];
  };
}
