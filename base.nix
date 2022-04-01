{ config, pkgs, ... }:

{
  imports = [
    ./users
  ];

  networking.domain = "pvv.ntnu.no";
  networking.useDHCP = false;

  time.timeZone = "Europe/Oslo";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "no";
  };

  system.autoUpgrade.enable = true;
  nix.gc.automatic = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    nano
    wget
    tmux
    file
    kitty.terminfo
  ];

  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";

}
