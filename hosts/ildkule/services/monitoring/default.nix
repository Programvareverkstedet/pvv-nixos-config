{ config, pkgs, ... }:

{
  imports = [
    ./grafana.nix
    ./loki.nix
    ./prometheus
    ./scrutiny.nix
  ];
}
