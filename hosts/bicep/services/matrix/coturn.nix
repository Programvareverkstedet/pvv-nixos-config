{ config, lib, fp, pkgs, secrets, values, ... }:

{
  sops.secrets."matrix/synapse/turnconfig" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "synapse/turnconfig";
    owner = config.users.users.matrix-synapse.name;
    group = config.users.users.matrix-synapse.group;
  };
  sops.secrets."matrix/coturn/static-auth-secret" = {
    sopsFile = fp /secrets/bicep/matrix.yaml;
    key = "coturn/static-auth-secret";
    owner = config.users.users.turnserver.name;
    group = config.users.users.turnserver.group;
  };

  services.matrix-synapse-next = {
    extraConfigFiles = [
      config.sops.secrets."matrix/synapse/turnconfig".path
    ];

    settings = {
      turn_uris = [
        "turns:turn.pvv.ntnu.no:443?transport=tcp"
        "turns:turn.pvv.ntnu.no:443?transport=udp"

        "turns:turn.pvv.ntnu.no:5349?transport=tcp"
        "turns:turn.pvv.ntnu.no:5349?transport=udp"

        "turns:turn.pvv.ntnu.no:3478?transport=udp"
        "turns:turn.pvv.ntnu.no:3478?transport=tcp"
        "turn:turn.pvv.ntnu.no:3478?transport=udp"
        "turn:turn.pvv.ntnu.no:3478?transport=tcp"

        "turns:turn.pvv.ntnu.no:3479?transport=tcp"
        "turns:turn.pvv.ntnu.no:3479?transport=udp"
        "turn:turn.pvv.ntnu.no:3479?transport=tcp"
        "turn:turn.pvv.ntnu.no:3479?transport=udp"
      ];
    };
  };

  security.acme.certs.${config.services.coturn.realm} = {
    email = "drift@pvv.ntnu.no";
    listenHTTP = "129.241.210.213:80";
    reloadServices = [ "coturn.service" ];
  };

  users.users.turnserver.extraGroups = [ "acme" ];

  # It needs this to be allowed to access the files with the acme group
  systemd.services.coturn.serviceConfig.PrivateUsers = lib.mkForce false;

  systemd.services."acme-${config.services.coturn.realm}".serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
  };

  services.coturn = rec {
    enable = true;
    realm = "turn.pvv.ntnu.no";

    cert = "${config.security.acme.certs.${realm}.directory}/full.pem";
    pkey = "${config.security.acme.certs.${realm}.directory}/key.pem";

    use-auth-secret = true;
    static-auth-secret-file = config.sops.secrets."matrix/coturn/static-auth-secret".path;

    secure-stun = true;

    listening-ips = [
      values.services.turn.ipv4
      values.services.turn.ipv6
    ];

    tls-listening-port = 443;
    alt-tls-listening-port = 5349;

    listening-port = 3478;

    min-port = 49000;
    max-port = 50000;

    no-tls = false;
    no-dtls = false;

    no-tcp-relay = false;

    extraConfig = ''
      verbose

      # ban private IP ranges
      no-multicast-peers
      denied-peer-ip=0.0.0.0-0.255.255.255
      denied-peer-ip=10.0.0.0-10.255.255.255
      denied-peer-ip=100.64.0.0-100.127.255.255
      denied-peer-ip=127.0.0.0-127.255.255.255
      denied-peer-ip=169.254.0.0-169.254.255.255
      denied-peer-ip=172.16.0.0-172.31.255.255
      denied-peer-ip=192.0.0.0-192.0.0.255
      denied-peer-ip=192.0.2.0-192.0.2.255
      denied-peer-ip=192.88.99.0-192.88.99.255
      denied-peer-ip=192.168.0.0-192.168.255.255
      denied-peer-ip=198.18.0.0-198.19.255.255
      denied-peer-ip=198.51.100.0-198.51.100.255
      denied-peer-ip=203.0.113.0-203.0.113.255
      denied-peer-ip=240.0.0.0-255.255.255.255
      denied-peer-ip=::1
      denied-peer-ip=64:ff9b::-64:ff9b::ffff:ffff
      denied-peer-ip=::ffff:0.0.0.0-::ffff:255.255.255.255
      denied-peer-ip=100::-100::ffff:ffff:ffff:ffff
      denied-peer-ip=2001::-2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff
      denied-peer-ip=2002::-2002:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff

      denied-peer-ip=10.0.0.0-10.255.255.255
      denied-peer-ip=192.168.0.0-192.168.255.255
      denied-peer-ip=172.16.0.0-172.31.255.255

      #user-quota=120
      #total-quota=1200
    '';
  };

  networking.firewall = {
    interfaces.enp6s0f0 = let
      range = with config.services.coturn; [ {
      from = min-port;
      to = max-port;
    } ];
    in
    {
      allowedUDPPortRanges = range;
      allowedUDPPorts = [ 443 3478 3479 5349 ];
      allowedTCPPortRanges = range;
      allowedTCPPorts = [ 443 3478 3479 5349 ];
    };
  };

}
