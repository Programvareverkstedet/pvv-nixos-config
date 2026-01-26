{ config, pkgs, ... }:
{
  users.users.albertba = {
    isNormalUser = true;
    extraGroups = [ "wheel" "drift" "nix-builder-users" ];

    packages = with pkgs; [
      fd
    ];

    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICheSCAxsYc/6g8hq2lXXHoUWPjWvntzzTA7OhG8waMN albert@Arch"
    ];
  };

}
