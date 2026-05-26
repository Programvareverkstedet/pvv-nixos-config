{ config, pkgs, lib, values, ... }:
let
  cfg = config.services.uptime-kuma;
  domain = "status.pvv.ntnu.no";
  stateDir = "/data/monitoring/uptime-kuma";
in {
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "5059";
      HOST = "127.0.1.2";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    locations."/".proxyPass = "http://${cfg.settings.HOST}:${cfg.settings.PORT}";
  };

  fileSystems."/var/lib/private/uptime-kuma" = {
    device = stateDir;
    fsType = "bind";
    options = [ "bind" ];
  };

  services.rsync-pull-targets = {
    enable = true;
    locations.${stateDir} = {
      user = "root";
      rrsyncArgs.ro = true;
      authorizedKeysAttrs = [
        "restrict"
        "from=\"principal.pvv.ntnu.no,${values.hosts.principal.ipv6},${values.hosts.principal.ipv4}\""
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXzcDm6cVr4NmWzUSroy33FlielKqaG83wY0RCMC0p/ uptime_kuma rsync backup";
    };
  };
}
