{pkgs, ...}:

{
  users.users.danio = {
    isNormalUser = true;
    extraGroups = [ "drift" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };
}
