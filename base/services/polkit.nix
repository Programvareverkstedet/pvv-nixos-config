{ config, lib, ... }:
let
  cfg = config.security.polkit;
in
{
  security.polkit.enable = true;

  environment.etc."polkit-1/rules.d/9-nixos-overrides.rules".text = lib.mkIf cfg.enable ''
    polkit.addRule(function(action, subject) {
       if (
           action.id.startsWith("org.freedesktop.systemd1.") &&
           subject.isInGroup("wheel")
       ) {
           return polkit.Result.AUTH_SELF_KEEP;
         }
     });
  '';
}
