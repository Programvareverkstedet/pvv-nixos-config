{ config, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ./base.nix
      ../../misc/metrics-exporters.nix
    ];

  sops.defaultSopsFile = ../../secrets/elysium/elysium.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "elysium"; # Define your hostname.

  #update this to actual network card.
  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.elysium; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
          zsh
          bash
          fish
          tcsh

          alpine
          mutt
          mutt-ics
          mutt-wizard
          notmuch
          mailutils
          procmail

          irssi
          weechat
          weechatScripts.edit

          coreutils-full
          diffutils
          findutils
          ripgrep
          cvs
          gawk
          git
          gnupg
          gnused
          groff
          less
          p7zip
          rcs
          screen
          tmux
          tree
          unzip
          zip

          emacs
          helix
          joe
          micro
          nano
          neovim

          autossh
          inetutils
          lynx
          mosh
          rsync
          w3m

          clang
          gcc
          guile
          lua
          perl
          php
          python3
          (python3.withPackages (ps: with ps; [
            numpy
            sympy
            scipy
            requests
            imageio
            pillow
            httpx
            pycryptodome
            pandas
            matplotlib
          ]))
          ruby
          tcl


          openscad
          cura
          where-is-my-sddm-theme
          firefox

  ];




  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    nerdfonts
    ubuntu_font_family

  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  security.polkit.enable = true;
  
  services.displayManager = {
    enable = true;
    sessionPackages = with pkgs; [ sway ];
    sddm = {
      enable = true;
      theme = "${pkgs.where-is-my-sddm-theme}";
      wayland.enable = true;
      wayland.compositor = "kwin";
      autoNumlock = true;
      enableHidpi = true;
    };
  };

  services.desktopManager.plasma6.enable = true;
  services.desktopManager.plasma6.enableQt5Integration = true;

  qt.platformTheme = "kde";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us,no";
    variant = ",";
  };


  # List services that you want to enable:

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
