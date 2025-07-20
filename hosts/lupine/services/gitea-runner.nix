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
      labels = [
        "debian-latest:docker://node:current-bookworm"
        "ubuntu-latest:docker://node:current-bookworm"
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

  networking.firewall.interfaces."podman+".allowedUDPPorts = [53 5353];
}
