{ config, ... }: let
  stateDir = "/data/monitoring/prometheus";
in {
  imports = [
    ./exim.nix
    ./gitea.nix
    ./machines.nix
    ./matrix-ooye.nix
    ./matrix-synapse.nix
    ./mysqld.nix
    ./phpfpm.nix
    ./postgres.nix
  ];

  services.prometheus = {
    enable = true;

    listenAddress = "127.0.0.1";
    port = 9001;
    retentionTime = "90d";
    extraFlags = [ "--storage.tsdb.retention.size=100GB" ];

    globalConfig = {
      scrape_interval = "10s";
      evaluation_interval = "10s";
    };

    ruleFiles = [ rules/synapse-v2.rules ];
  };

  fileSystems."/var/lib/prometheus2" = {
    device = stateDir;
    fsType = "bind";
    options = [ "bind" ];
  };
}
