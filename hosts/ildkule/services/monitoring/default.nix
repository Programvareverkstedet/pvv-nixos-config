{ config, pkgs, ... }:

{
  imports = [
    ./grafana.nix
    ./loki.nix
    ./prometheus
    ./uptime-kuma.nix
  ];
}
