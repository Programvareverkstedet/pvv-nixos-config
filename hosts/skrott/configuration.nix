{ pkgs, lib, fp, ... }: {
  imports = [
    # ./hardware-configuration.nix

    (fp /base)
  ];

  boot = {
    consoleLogLevel = 0;
    enableContainers = false;
    loader.grub.enable = false;
    kernelPackages = pkgs.linuxPackages;
  };

  # Now turn off a bunch of stuff lol
  system.autoUpgrade.enable = lib.mkForce false;
  services.irqbalance.enable = lib.mkForce false;
  services.logrotate.enable = lib.mkForce false;
  services.nginx.enable = lib.mkForce false;
  services.postfix.enable = lib.mkForce false;

  # TODO: can we reduce further?

  system.stateVersion = "25.05";

  # sops.defaultSopsFile = fp /secrets/skrott/skrott.yaml;
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # sops.age.generateKey = true;

  # zramSwap.enable = true;

  networking = {
    hostName = "skrot";
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "129.241.210.235";
        prefixLength = 25;
      }];
    };
  };

  services.dibbler = {
    enable = true;
    kioskMode = true;
    limitScreenWidth = 80;
    limitScreenHeight = 42;
  };

  # https://github.com/NixOS/nixpkgs/issues/84105
  boot.kernelParams = [
    "console=ttyUSB0,9600"
    # "console=tty1" # Already part of the module
  ];
  systemd.services."serial-getty@ttyUSB0" = {
    enable = true;
    wantedBy = [ "getty.target" ]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };
}
