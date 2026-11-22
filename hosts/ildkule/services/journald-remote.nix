{ config, lib, values, ... }:
let
  cfg = config.services.journald.remote;
  domainName = "journald.pvv.ntnu.no";
  socketPath = "/run/systemd-journal-remote/journal-remote.sock";
in
{
  services.journald.upload.enable = lib.mkForce false;

  services.journald.remote = {
    enable = true;
    listen = "http";
    output = "/var/log/journal/remote/remote.journal";
    settings.Remote.SplitMode = "none";
  };

  systemd.sockets."systemd-journal-remote" = {
    listenStreams = lib.mkForce [
      ""
      socketPath
    ];
    socketConfig = {
      SocketUser = "root";
      SocketGroup = config.services.nginx.group;
      SocketMode = "0660";
    };
  };

  services.nginx = {
    enable = true;
    upstreams.journald-remote.servers."unix:${socketPath}" = { };

    virtualHosts.${domainName} = {
      enableACME = true;
      # https://github.com/systemd/systemd/issues/39166
      http2 = false;

      locations = {
        "/".return = "403";
        "= /upload" = {
          proxyPass = "http://journald-remote/upload";
          extraConfig = ''
            client_max_body_size 0;
            proxy_request_buffering off;

            allow 127.0.0.1;
            allow ::1;
            allow ${values.ipv4-space};
            allow ${values.ipv6-space};
            allow ${values.hosts.gluttony.ipv4};
            allow ${values.hosts.gluttony.ipv6};
            deny all;
          '';
        };
      };
    };
  };
}
