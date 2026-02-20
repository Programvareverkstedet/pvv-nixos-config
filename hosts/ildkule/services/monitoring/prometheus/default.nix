{ config, ... }:
let
  stateDir = "/data/monitoring/prometheus";
in
{
  imports = [
    ./exim.nix
    ./gitea.nix
    ./machines.nix
    ./matrix-synapse.nix
    ./mysqld.nix
    ./postgres.nix
  ];

  services.prometheus = {
    enable = true;

    listenAddress = "127.0.0.1";
    port = 9001;

    ruleFiles = [ rules/synapse-v2.rules ];
  };

  fileSystems."/var/lib/prometheus2" = {
    device = stateDir;
    options = [ "bind" ];
  };
}
