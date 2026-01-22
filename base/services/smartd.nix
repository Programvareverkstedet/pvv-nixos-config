{ config, pkgs, lib, ... }:
{
  services.smartd = {
    # NOTE: qemu guests tend not to have SMART-reporting disks. Please override for the
    #       hosts with disk passthrough.
    enable = lib.mkDefault (!config.services.qemuGuest.enable);
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
