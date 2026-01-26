{ config, pkgs, ... }:

{
  users.users.alfhj = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMCAYE0U3sFizm/NSbKCs0jEhZ1mpAWPcijFevejiFL1 alfhj"
    ];
  };
}
