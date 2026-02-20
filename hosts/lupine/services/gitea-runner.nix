{ config, lupineName, ... }:
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
      # NOTE: gitea actions runners need node inside their docker images,
      #       so we are a bit limited here.
      labels = [
        "debian-latest:docker://node:current-trixie"
        "debian-trixie:docker://node:current-trixie"
        "debian-bookworm:docker://node:current-bookworm"
        "debian-bullseye:docker://node:current-bullseye"

        "debian-latest-slim:docker://node:current-trixie-slim"
        "debian-trixie-slim:docker://node:current-trixie-slim"
        "debian-bookworm-slim:docker://node:current-bookworm-slim"
        "debian-bullseye-slim:docker://node:current-bullseye-slim"

        "alpine-latest:docker://node:current-alpine"
        "alpine-3.22:docker://node:current-alpine3.22"
        "alpine-3.21:docker://node:current-alpine3.21"

        # See https://gitea.com/gitea/runner-images
        "ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"
        "ubuntu-24.04:docker://docker.gitea.com/runner-images:ubuntu-24.04"
        "ubuntu-noble:docker://docker.gitea.com/runner-images:ubuntu-24.04"
        "ubuntu-22.04:docker://docker.gitea.com/runner-images:ubuntu-22.04"
        "ubuntu-jammy:docker://docker.gitea.com/runner-images:ubuntu-22.04"

        "ubuntu-latest-slim:docker://docker.gitea.com/runner-images:ubuntu-latest-slim"
        "ubuntu-24.04-slim:docker://docker.gitea.com/runner-images:ubuntu-24.04-slim"
        "ubuntu-noble-slim:docker://docker.gitea.com/runner-images:ubuntu-24.04-slim"
        "ubuntu-22.04-slim:docker://docker.gitea.com/runner-images:ubuntu-22.04-slim"
        "ubuntu-jammy-slim:docker://docker.gitea.com/runner-images:ubuntu-22.04-slim"
      ];
      tokenFile = config.sops.templates."gitea-runner-envfile".path;
    };
  };

  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune.enable = true;
  };

  networking.dhcpcd.IPv6rs = false;

  networking.firewall.interfaces."podman+".allowedUDPPorts = [
    53
    5353
  ];
}
