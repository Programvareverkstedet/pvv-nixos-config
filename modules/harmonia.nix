{ config, pkgs, values, inputs, lib, ... }:
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

  systemd.services = let
    inputUrls = lib.mapAttrs (input: value: value.url) (import "${inputs.self}/flake.nix").inputs;
    nixpkgsInputUrls = lib.intersectAttrs {
      nixpkgs = { };
      nixpkgs-unstable = { };
    } inputUrls;
  in {
    nixos-build-all = {
      description = "Pre-build all NixOS configurations";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      startAt = "00:40";

      serviceConfig = {
        Type = "oneshot";
        SyslogIdentifier = "nixos-build-all";
        CacheDirectory = "nixos-build-all";
        Restart = "on-failure";
        RestartSec = "1min";
        ExecStart =
          let
            buildAllFlags = [
              "--out-link" "/var/cache/nixos-build-all/all-machines"
              "-L"
              "--keep-going"
              "--refresh"
              "--no-write-lock-file"
              "--print-out-paths"
            ] ++ (lib.pipe nixpkgsInputUrls [
              (lib.mapAttrsToList (input: url: [ "--override-input" input url ]))
              lib.concatLists
            ]);
          in
          "${lib.getExe config.nix.package} build git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git?ref=main#all-machines ${lib.escapeShellArgs buildAllFlags}";
      };
    };

    nixos-build-all-channel-poll = {
      description = "Trigger nixos-build-all on nixpkgs channel updates";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      startAt = "hourly";

      serviceConfig = {
        Type = "oneshot";
        SyslogIdentifier = "nixos-build-all-channel-poll";
        StateDirectory = "nixos-build-all-channel-poll";
        ExecStart = lib.getExe (pkgs.writeShellApplication {
          name = "nixos-build-all-channel-poll";
          runtimeInputs = with pkgs; [
            coreutils
            curl
            config.systemd.package
          ];
          text = let
            revisionUrls = lib.mapAttrsToList (_: url: "${lib.removeSuffix "/nixexprs.tar.xz" url}/git-revision") nixpkgsInputUrls;
            curlArgs = lib.cli.toCommandLineShellGNU { } {
              fail = true;
              fail-early = true;
              location = true;
              silent = true;
              show-error = true;
              retry = 3;
              user-agent = "NixOS-Channel-Update-Poller/1.0 (+https://git.pvv.ntnu.no/Drift/pvv-nixos-config)";
              write-out = " %{url}\\n";
            };
          in ''
            revisions="$(curl ${curlArgs} ${lib.escapeShellArgs revisionUrls})"
            old_revisions="$(cat "$STATE_DIRECTORY/revisions" 2>/dev/null || true)"

            if [ "$revisions" != "$old_revisions" ]; then
              echo "Channels updated, rebuilding"
              echo "Old revisions:"
              echo "''${old_revisions:-(none)}"
              echo "New revisions:"
              echo "$revisions"
              systemctl restart --no-block nixos-build-all.service
              echo "$revisions" > "$STATE_DIRECTORY/revisions"
            fi
          '';
        });
      };
    };
  };

  systemd.timers.nixos-build-all-channel-poll.timerConfig.RandomizedDelaySec = "1h";
}
