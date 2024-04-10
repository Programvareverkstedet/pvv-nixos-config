{ pkgs, config, ... }:
{
  imports = [
    ./ingress.nix
  ];

  services.nginx.enable = true;
}
