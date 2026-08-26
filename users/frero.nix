{ config, pkgs, ... }:
{
  users.users.frero = {
    isNormalUser = true;
    extraGroups = [ "wheel" "drift" "nix-builder-users" ];
    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKULJg19S/Ny9bbIH48OXa1iNsXuyr8e3Ym7mJCIgbnX" # laptop
    ];
  };
}
