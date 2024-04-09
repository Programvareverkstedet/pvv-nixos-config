{ pkgs, ... }:
{
  users.users.adriangl = {
    isNormalUser = true;
    description = "(0_0)";
    extraGroups = [
      "wheel"
      "drift"
      "nix-builder-users"
    ];

    packages = with pkgs; [
      neovim
      htop
      ripgrep
      vim
      foot.terminfo
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFa5y7KyLn2tjxed1czMbyM5scnEpo9v/GfnhL/28ckM legolas"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICf7SlyHR6KgP7+IeFr/Iuiu2lL5vaSlzqPonaO8XU0J gunalx@aragon"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEj+Y0RUrSaF8gUW8m2BY6i8e7/0bUWhu8u8KW+AoHDh gunalx@nixos"
    ];
  };
}
