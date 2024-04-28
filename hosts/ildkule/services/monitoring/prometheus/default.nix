{ config, ... }: {
  imports = [
    ./gogs.nix
    ./matrix-synapse.nix
    # TODO: enable once https://github.com/NixOS/nixpkgs/pull/242365 gets merged
    # ./mysqld.nix
    ./node.nix
    ./postgres.nix
  ];

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9001;

    ruleFiles = [ rules/synapse-v2.rules ];
  };
}