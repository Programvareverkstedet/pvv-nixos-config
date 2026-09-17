{ config, values, ... }:
{
  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.sops.secrets."harmonia/signing-key".path ];
    settings.bind = "unix:///run/harmonia.sock";
  };

  systemd.sockets.harmonia.socketConfig = {
    SocketMode = "0660";
    SocketGroup = "nginx";
  };

  sops.secrets."harmonia/signing-key" = {
    restartUnits = [ "harmonia.service" ];
  };

  services.nginx = {
    enable = true;

    virtualHosts.${config.networking.fqdn} = {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/" = {
        proxyPass = "http://unix:/run/harmonia.sock:/";
        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.ipv4-space};
          allow ${values.ipv6-space};
          allow ${values.ntnu.ipv4-space};
          allow ${values.ntnu.ipv6-space};
          allow ${values.hosts.ildkule.ipv4}/32;
          allow ${values.hosts.ildkule.ipv6}/128;
          deny all;
        '';
      };
    };
  };
}
