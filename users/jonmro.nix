{ config, pkgs, ... }:

{
  users.users.jonmro = {
    isNormalUser = true;
    extraGroups = [ "wheel" "drift" "nix-builder-users" ];
    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEm5PfYmfl/0fnAP/3coVlvTw3/TYNLT6r/NwJHZbLAK jonrodtang@gmail.com"
    ];
  };
}
