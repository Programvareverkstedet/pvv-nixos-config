{ pkgs, ... }:
{
  users.users.frero = {
    isNormalUser = true;
    extraGroups = [ "wheel" "drift" "nix-builder-users" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII09JbtSUMurvmHpJ7TmUQctXpNVhjFYhoJ3+1ZITmMx"
    ];
  };
}
