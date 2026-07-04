{ config, pkgs, lib, values, ... }:
let
  renderConfig = attrs: lib.pipe attrs [
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
      else throw "Unknown value in lupine openvpn config:\n${value}"
    ))
    (lib.mapAttrsToList (name: value: if value == true then name else "${name} ${value}"))
    (builtins.concatStringsSep "\n")
    (x: x + "\n\n")
  ];
in
{
  sops.secrets = {
    "openvpn/ca/crt" = { };
    "openvpn/server/crt" = { };
    "openvpn/server/key" = { };
  };

  services.openvpn.servers."ov-tunnel" = {
    config = renderConfig {
      # TODO: use aliases
      local = values.services.knutsen-vpn;
      port = 1194;
      proto = "udp";

      dev = "tap0";
      dev-type = "tap";

      script-security = 0;

      ca = config.sops.secrets."openvpn/ca/crt".path;
      cert = config.sops.secrets."openvpn/server/crt".path;
      key = config.sops.secrets."openvpn/server/key".path;
      dh = "none";

      # Maintain a record of client <-> virtual IP address
      # associations in this file.  If OpenVPN goes down or
      # is restarted, reconnecting clients can be assigned
      # the same virtual IP address from the pool that was
      # previously assigned.

      # ifconfig-pool-persist = ./ipp.txt;

      server-bridge = builtins.concatStringsSep " " [
        # Gateway
        "129.241.210.129"
        # Netmask
        "255.255.255.128"
        # Pool start
        values.services.knutsen-tap
        # Pool end
        values.services.ludvigsen-tap
      ];

      keepalive = "10 120";
      data-ciphers = "none";

      user = "nobody";
      group = "nobody";

      status = "/var/log/openvpn-status.log";

      client-config-dir = pkgs.writeTextDir "ludvigsen" ''
        # Sett IP-adr. for tap0 til ludvigsens PVV-addresse.
        ifconfig-push ${values.services.ludvigsen-tap} 255.255.255.128

        # Hvordan skal man faa dette til aa funke, tro?
        # ifconfig-ipv6-push 2001:700:300:1900::xxx/64

        # La ludvigsen bruke std. PVV-gateway til all trafikk (unntatt VPN-tunnellen).
        push "redirect-gateway"
      '';

      persist-key = true;
      persist-tun = true;

      verb = 5;

      explicit-exit-notify = 1;
    };
  };
}
