{ config, pkgs, ... }:

{
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./loki.nix
  ];
}
