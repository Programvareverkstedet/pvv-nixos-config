{
  pkgs,
  lib,
  fp,
  ...
}:

{
  imports = [
    (fp /users)
    (fp /modules/snakeoil-certs.nix)

    ./flake-input-exporter.nix
    ./networking.nix
    ./nix.nix
    ./programs.nix
    ./sops.nix
    ./vm.nix

    ./services/acme.nix
    ./services/auto-upgrade.nix
    ./services/dbus.nix
    ./services/fwupd.nix
    ./services/irqbalance.nix
    ./services/journald-upload.nix
    ./services/logrotate.nix
    ./services/nginx.nix
    ./services/openssh.nix
    ./services/polkit.nix
    ./services/postfix.nix
    ./services/prometheus-node-exporter.nix
    ./services/prometheus-systemd-exporter.nix
    ./services/promtail.nix
    ./services/roowho2.nix
    ./services/smartd.nix
    ./services/thermald.nix
    ./services/uptimed.nix
    ./services/userborn.nix
    ./services/userdbd.nix
  ];

  boot.tmp.cleanOnBoot = lib.mkDefault true;
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  time.timeZone = "Europe/Oslo";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "no";
  };

  # Don't install the /lib/ld-linux.so.2 stub
  environment.ldso32 = null;

  # .bash_profile already works, but lets also use .bashrc like literally every other distro
  # https://man.archlinux.org/man/core/bash/bash.1.en#INVOCATION
  # home-manager usually handles this for you: https://github.com/nix-community/home-manager/blob/22a36aa709de7dd42b562a433b9cefecf104a6ee/modules/programs/bash.nix#L203-L209
  # btw, programs.bash.shellInit just goes into environment.shellInit which in turn goes into /etc/profile, spooky shit
  programs.bash.shellInit = ''
    if [ -n "''${BASH_VERSION:-}" ]; then
      if [[ ! -f ~/.bash_profile && ! -f ~/.bash_login ]]; then
       [[ -f ~/.bashrc ]] && . ~/.bashrc
      fi
    fi
  '';

  # security.lockKernelModules = true;
  security.protectKernelImage = true;
  security.sudo.execWheelOnly = true;
  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  # These are servers, sleep is for the weak
  systemd.sleep.extraConfig = lib.mkDefault ''
    AllowSuspend=no
    AllowHibernation=no
  '';

  users.mutableUsers = lib.mkDefault false;

  users.groups."drift".name = "drift";

  # Trusted users on the nix builder machines
  users.groups."nix-builder-users".name = "nix-builder-users";
}
