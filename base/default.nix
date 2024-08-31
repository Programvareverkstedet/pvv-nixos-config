{ pkgs, ... }:

{
  imports = [
    ../users
    ../modules/snakeoil-certs.nix

    ./networking.nix
    ./nix.nix

    ./services/acme.nix
    ./services/auto-upgrade.nix
    ./services/logrotate.nix
    ./services/nginx.nix
    ./services/openssh.nix
    ./services/smartd.nix
    ./services/thermald.nix
  ];

  time.timeZone = "Europe/Oslo";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "no";
  };

  environment.systemPackages = with pkgs; [
    file
    git
    gnupg
    htop
    nano
    ripgrep
    rsync
    screen
    tmux
    vim
    wget

    kitty.terminfo
  ];

  programs.zsh.enable = true;

  users.groups."drift".name = "drift";

  # Trusted users on the nix builder machines
  users.groups."nix-builder-users".name = "nix-builder-users";
}

