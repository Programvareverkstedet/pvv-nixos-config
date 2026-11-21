{ config, lib, values, ... }:
let
  cfg = config.services.matrix-tuwunel;
  domain = "alerts.pvv.ntnu.no";
  socketPath = "/run/tuwunel.sock";
in
{
  services.matrix-tuwunel = {
    enable = true;
    settings.global = {
      server_name = domain;
      unix_socket_path = socketPath;
      ip_source = "rightmost_x_forwarded_for";
      allow_federation = true;
      allow_registration = false;
      # login_with_password = false;
      ip_range_denylist = [
        "127.0.0.0/8"
        "0.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "192.0.0.0/24"
        "169.254.0.0/16"
        "192.88.99.0/24"
        "198.18.0.0/15"
        "192.0.2.0/24"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "::1/128"
        "::/128"
        "fe80::/10"
        "fc00::/7"
        "2001:db8::/32"
        "ff00::/8"
        "fec0::/10"
        "${values.hosts.ildkule.ipv4}/32"
        "${values.hosts.ildkule.ipv6}/128"
      ];
      well_known = {
        client = "https://${domain}";
        server = "${domain}:443";
      };
    };
  };

  systemd.sockets.tuwunel = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [
      socketPath
      "127.0.0.1:${toString (lib.head cfg.settings.global.port)}"
    ];
    socketConfig = {
      SocketUser = cfg.user;
      SocketGroup = cfg.group;
      SocketMode = "0660";
    };
  };

  systemd.services.tuwunel = {
    requires = [ "tuwunel.socket" ];
    after = [ "tuwunel.socket" ];
  };

  users.users.nginx.extraGroups = [ cfg.group ];

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    locations = {
      "/".return = "404";
      "= /".proxyPass = "http://unix:${socketPath}:";
      "/_matrix/" = {
        proxyPass = "http://unix:${socketPath}:";
        extraConfig = ''
          client_max_body_size ${toString cfg.settings.global.max_request_size};
          proxy_buffering off;
        '';
      };
      "/.well-known/matrix/".proxyPass = "http://unix:${socketPath}:";
    };
  };
}
