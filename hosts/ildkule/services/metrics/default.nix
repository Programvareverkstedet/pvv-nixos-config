{ config, pkgs, ... }:

{
  imports = [
    ./prometheus
    ./grafana.nix
    ./loki.nix
  ];
}
