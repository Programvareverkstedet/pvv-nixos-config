{ config, ... }: {
  imports = [
    ./node.nix
    ./matrix-synapse.nix
    ./postgres.nix
    ./gogs.nix
  ];

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9001;

    ruleFiles = [ rules/synapse-v2.rules ];
  };
}
