{ config, pkgs, inputs, ... }:

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
    flake = "git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git";
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "unstable"
      "--no-write-lock-file"
    ];
  };
  nix.gc.automatic = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  /* This makes commandline tools like
  ** nix run nixpkgs#hello
  ** and nix-shell -p hello
  ** use the same channel the system
  ** was built with
  */
  nix.registry = {
    nixpkgs.flake = inputs.nixpkgs;
  };
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

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
