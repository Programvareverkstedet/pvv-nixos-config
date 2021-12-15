{pkgs, ...}:

{
  users.users.oysteikt = {
    isNormalUser = true;
    #extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };
}
