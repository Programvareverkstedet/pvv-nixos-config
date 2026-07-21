{ config, pkgs, lib, ... }:
let
  cfg = config.services.irqbalance;
in
{
  services.irqbalance.enable = true;

  # irqbalance only has meaningful work to do on multi-socket machines, so
  # skip starting it pointlessly everywhere else.
  systemd.services.irqbalance.serviceConfig.ExecCondition = let
    isMultiSocket = pkgs.writeShellApplication {
      name = "irqbalance-is-multi-socket";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        sockets=$(cat /sys/devices/system/cpu/cpu*/topology/physical_package_id | sort -u | wc -l)
        [ "$sockets" -gt 1 ]
      '';
    };
  in lib.mkIf cfg.enable [
    (lib.getExe isMultiSocket)
  ];
}
