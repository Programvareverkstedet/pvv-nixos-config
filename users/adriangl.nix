{ pkgs, ... }:
{
  users.users.adriangl = {
    isNormalUser = true;
    description = "(0_0)";
    extraGroups = [
      "wheel"
      "drift"
    ];

    packages = with pkgs; [
      exa
      neovim
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFa5y7KyLn2tjxed1czMbyM5scnEpo9v/GfnhL/28ckM legolas"
    ];
  };
}
