{ config, lib, values, ... }:
let
  mkRunner = name: {
    # This is unfortunately state, and has to be generated one at a time :(
    # To do that, comment out all except one of the runners, fill in its token
    # inside the sops file, rebuild the system, and only after this runner has
    # successfully registered will gitea give you the next token.
    # - oysteikt Sep 2023
    sops.secrets."gitea/runners/${name}".restartUnits = [
      "gitea-runner-${name}.service"
    ];

    services.gitea-actions-runner.instances = {
      ${name} = {
        enable = true;
        name = "git-runner-${name}"; url = "https://git.pvv.ntnu.no";
        labels = [
          "debian-latest:docker://node:18-bullseye"
          "ubuntu-latest:docker://node:18-bullseye"
        ];
        tokenFile = config.sops.secrets."gitea/runners/${name}".path;
      };
    };
  };
in
lib.mkMerge [
  (mkRunner "alpha")
  (mkRunner "beta")
  (mkRunner "epsilon")
  { virtualisation.podman.enable = true; }
]
