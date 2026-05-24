{ values, ... }:
let
  webExport = "/var/lib/bluemap/web";
in {
  # NOTE: our version of the module gets added in flake.nix
  disabledModules = [ "services/web-apps/bluemap.nix" ];

  services.nginx.virtualHosts."minecraft.pvv.ntnu.no" = {
    enableACME = true;
    forceSSL = true;
    kTLS = true;
    http3 = true;
    quic = true;
    http3_hq = true;
    extraConfig = ''
      # Enabling QUIC 0-RTT
      ssl_early_data on;

      quic_gso on;
      quic_retry on;
      add_header Alt-Svc 'h3=":$server_port"; ma=86400';
    '';
    root = webExport;
    locations = {
      "~* ^/maps/[^/]*/tiles/".extraConfig = ''
        error_page 404 = @empty;
      '';
      "@empty".return = "204";
    };
  };

  services.rsync-pull-targets = {
    enable = true;
    locations.${webExport} = {
      user = "root";
      rrsyncArgs.wo = true;
      authorizedKeysAttrs = [
        "restrict"
        "from=\"gluttony.pvv.ntnu.no,${values.hosts.gluttony.ipv6},${values.hosts.gluttony.ipv4}\""
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5jrqMovXlWaFWZAV/aKyQReHvUQp5kb+7Ja4gnevSr root@gluttony bluemap";
    };
  };

  networking.firewall.allowedUDPPorts = [ 443 ];
}
