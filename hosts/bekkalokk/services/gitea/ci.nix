{ config, ... }:
{
  sops.secrets."gitea/runner-token" = { };

  services.gitea-actions-runner.instances = {
    runner1 = {
      url = "https://git-runner1.pvv.ntnu.no";
      name = "git-runner1";
      labels = [
        "debian-latest:docker://node:18-bullseye"
      ];
      enable = true;
			tokenFile = config.sops.secrets."gitea/runner-token".path;
    };
  };
}