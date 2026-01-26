{ config, pkgs, ... }:

{
  users.users.amalieem = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPsMtFIj4Dem/onwMoWYbosOcU4y7A5nTjVwqWaU33E1 amalieem@matey-aug22"
    ];
  };
}
