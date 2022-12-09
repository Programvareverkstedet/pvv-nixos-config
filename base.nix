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

  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git?ref=main";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
    ];
  };
  nix.gc.automatic = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    file
    git
    htop
    nano
    tmux
    vim
    wget

    kitty.terminfo
  ];

  users.groups."drift".name = "drift";

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
    extraConfig = ''
      PubkeyAcceptedAlgorithms=+ssh-rsa
    '';
  };


}
