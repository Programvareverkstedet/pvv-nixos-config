{ pkgs, ... }:
{
  users.users.vegardbm = {
    isNormalUser = true;
    description = "noe";
    extraGroups = [
      "wheel"
      "drift"
      "nix-builder-users"
    ];
    packages = with pkgs; [
      btop
      eza
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVA3HqEx3je6L1AC+bP8sTxu3ZTKvTCR0npCyOVAYK5 vbm@arch-xeon"
    ];
  };
}
