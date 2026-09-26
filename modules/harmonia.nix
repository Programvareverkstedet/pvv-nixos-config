{ config, values, inputs, lib, ... }:
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

  systemd.services.nixos-nightly-build-all = {
    description = "Pre-build all NixOS configurations";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    startAt = "00:40";

    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "1min";
      ExecStart =
        let
          inputUrls = lib.mapAttrs (input: value: value.url) (import "${inputs.self}/flake.nix").inputs;

          buildAllFlags = [
            "--no-link"
            "-L"
            "--keep-going"
            "--refresh"
            "--no-write-lock-file"
            "--print-out-paths"
          ] ++ (lib.pipe inputUrls [
            (lib.intersectAttrs {
              nixpkgs = { };
              nixpkgs-unstable = { };
            })
            (lib.mapAttrsToList (input: url: [ "--override-input" input url ]))
            lib.concatLists
          ]);
        in
        "${lib.getExe config.nix.package} build git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git?ref=main#all-machines ${lib.escapeShellArgs buildAllFlags}";
    };
  };
}
