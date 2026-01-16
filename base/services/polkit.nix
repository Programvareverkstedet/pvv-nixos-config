{ config, lib, ... }:
let
  cfg = config.security.polkit;
in
{
  security.polkit.enable = true;

  environment.etc."polkit-1/rules.d/9-nixos-overrides.rules".text = lib.mkIf cfg.enable ''
    polkit.addAdminRule(function(action, subject) {
        if(subject.isInGroup("wheel")) {
            return ["unix-user:"+subject.user];
        }
    });
  '';
}
