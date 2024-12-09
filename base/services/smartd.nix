{ config, pkgs, lib, ... }:
{
  services.smartd = {
    enable = lib.mkDefault true;
    notifications = {
      mail = {
        enable = true;
        sender = "root@pvv.ntnu.no";
        recipient = "root@pvv.ntnu.no";
      };
      wall.enable = false;
    };
  };

  environment.systemPackages = lib.optionals config.services.smartd.enable (with pkgs; [
    smartmontools
  ]);

  systemd.services.smartd.unitConfig.ConditionVirtualization = "no";
}
