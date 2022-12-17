{ pkgs, ... }:
{
  users.users.felixalb = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDKzPICGew7uN0cmvRmbwkwTCodTBUgEhkoftQnZuO4Q felixalbrigtsen@gmail.com"
    ];
  };
}
