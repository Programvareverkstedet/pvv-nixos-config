{pkgs, ...}:

{
  users.users.alfhj = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMCAYE0U3sFizm/NSbKCs0jEhZ1mpAWPcijFevejiFL1 alfhj"
    ];
  };
}

