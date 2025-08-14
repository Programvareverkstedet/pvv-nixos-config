{ pkgs, ... }:
{
  users.users.alb = {
    isNormalUser = true;
    extraGroups = [ "wheel" "drift" "nix-builder-users" ];

    packages = with pkgs; [
      htop
      neovim
      ripgrep
      fd
      tmux
    ];

    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICheSCAxsYc/6g8hq2lXXHoUWPjWvntzzTA7OhG8waMN albert@Arch"
    ];
  };

}

