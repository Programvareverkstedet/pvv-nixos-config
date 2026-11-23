{ config, ... }: let
  stateDir = "/data/monitoring/prometheus";
in {
  imports = [
    ./blackbox.nix
    ./dibbler.nix
    ./dovecot.nix
    ./exim.nix
    ./gitea.nix
    ./gitea-runner.nix
    ./home-assistant.nix
    ./loki.nix
    ./machines.nix
    ./matrix-livekit.nix
    ./matrix-mjolnir.nix
    ./matrix-ooye.nix
    ./matrix-synapse.nix
    ./mysqld.nix
    ./phpfpm.nix
    ./postgres.nix
    ./prometheus.nix
  ];

  services.prometheus = {
    enable = true;
    checkConfig = "syntax-only";

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
