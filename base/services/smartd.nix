{ config, pkgs, lib, ... }:
{
  services.smartd.enable = lib.mkDefault true;

  environment.systemPackages = lib.optionals config.services.smartd.enable (with pkgs; [
    smartmontools
  ]);
}