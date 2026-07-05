{ config, pkgs, ... }:

{
  imports = [
    ./gatus
    ./grafana.nix
    ./loki.nix
    ./prometheus
    ./scrutiny.nix
  ];
}
