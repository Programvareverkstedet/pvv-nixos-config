{ config, lib, values, lupineName, ... }:
let
  cfg = config.services.gitea-actions-runner.instances.${lupineName};
in
{
  # This is unfortunately state, and has to be generated one at a time :(
  # To do that, comment out all except one of the runners, fill in its token
  # inside the sops file, rebuild the system, and only after this runner has
  # successfully registered will gitea give you the next token.
  # - oysteikt Sep 2023
  sops = {
    secrets."gitea/runners/token" = {
      key = "gitea/runners/${lupineName}";
    };

    templates."gitea-runner-envfile" = {
      restartUnits = [
        "gitea-runner-${lupineName}.service"
      ];
      content = ''
        TOKEN="${config.sops.placeholder."gitea/runners/token"}"
      '';
    };
  };

  services.gitea-actions-runner.instances = {
    ${lupineName} = {
      enable = true;
      name = "git-runner-${lupineName}";
      url = "https://git.pvv.ntnu.no";

      # https://git.pvv.ntnu.no/Drift/gitea-joggers
      labels = [
        "debian-latest:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-trixie"
        "debian-trixie:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-trixie"
        "debian-bookworm:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-bookworm"
        "debian-bullseye:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-bullseye"

        "debian-latest-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-trixie-slim"
        "debian-trixie-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-trixie-slim"
        "debian-bookworm-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-bookworm-slim"
        "debian-bullseye-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:debian-current-bullseye-slim"

        "alpine-latest:docker://git.pvv.ntnu.no/drift/gitea-joggers:alpine-current-alpine"
        "alpine-3.23:docker://git.pvv.ntnu.no/drift/gitea-joggers:alpine-current-alpine3.23"
        "alpine-3.22:docker://git.pvv.ntnu.no/drift/gitea-joggers:alpine-current-alpine3.22"
        "alpine-3.21:docker://git.pvv.ntnu.no/drift/gitea-joggers:alpine-current-alpine3.21"

        "ubuntu-latest:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-26.04"
        "ubuntu-26.04:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-26.04"
        "ubuntu-resolute:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-26.04"
        "ubuntu-24.04:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-24.04"
        "ubuntu-noble:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-24.04"
        "ubuntu-22.04:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-22.04"
        "ubuntu-jammy:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-22.04"

        # No slim images for ubuntu, just cheat for now
        "ubuntu-latest-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-26.04"
        "ubuntu-26.04-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-26.04"
        "ubuntu-resolute-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-26.04"
        "ubuntu-24.04-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-24.04"
        "ubuntu-noble-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-24.04"
        "ubuntu-22.04-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-22.04"
        "ubuntu-jammy-slim:docker://git.pvv.ntnu.no/drift/gitea-joggers:ubuntu-22.04"
      ];
      tokenFile = config.sops.templates."gitea-runner-envfile".path;
      settings.metrics = {
        enabled = true;
        addr = "127.0.0.1:9101";
      };
    };
  };

  services.nginx = {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/gitea-runner/metrics" = {
        proxyPass = "http://${cfg.settings.metrics.addr}/metrics";

        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      };
    };
  };

  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune.enable = true;
  };

  networking.dhcpcd.IPv6rs = false;

  networking.firewall.interfaces."podman+".allowedUDPPorts = [53 5353];
}
