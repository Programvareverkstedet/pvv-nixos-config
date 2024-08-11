{ config, lib, pkgs, inputs, values, ... }:

{
  imports = [
    ./users
    ./modules/snakeoil-certs.nix
  ];

  networking.domain = "pvv.ntnu.no";
  networking.useDHCP = false;
  # networking.search = [ "pvv.ntnu.no" "pvv.org" ];
  # networking.nameservers = lib.mkDefault [ "129.241.0.200" "129.241.0.201" ];
  # networking.tempAddresses = lib.mkDefault "disabled";
  # networking.defaultGateway = values.hosts.gateway;

  systemd.network.enable = true;

  services.resolved = {
    enable = lib.mkDefault true;
    dnssec = "false"; # Supposdly this keeps breaking and the default is to allow downgrades anyways...
  };

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
      "--update-input" "nixpkgs-unstable"
      "--no-write-lock-file"
    ];
  };
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 2d";

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

  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAcceptedAlgorithms=+ssh-rsa
      Match Group wheel
        PasswordAuthentication no
      Match All
    '';
    settings.PermitRootLogin = "yes";
  };

  # nginx return 444 for all nonexistent virtualhosts

  systemd.services.nginx.after = [ "generate-snakeoil-certs.service" ];

  environment.snakeoil-certs = lib.mkIf config.services.nginx.enable {
    "/etc/certs/nginx" = {
      owner = "nginx";
      group = "nginx";
    };
  };

  services.nginx = {
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    appendConfig = ''
      pcre_jit on;
      worker_processes auto;
      worker_rlimit_nofile 100000;
    '';
    eventsConfig = ''
      worker_connections 2048;
      use epoll;
      multi_accept on;
    '';
  };

  systemd.services.nginx.serviceConfig = lib.mkIf config.services.nginx.enable {
    LimitNOFILE = 65536;
  };

  services.nginx.virtualHosts."_" = lib.mkIf config.services.nginx.enable {
    sslCertificate = "/etc/certs/nginx.crt";
    sslCertificateKey = "/etc/certs/nginx.key";
    addSSL = true;
    extraConfig = "return 444;";
  };

  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 443 ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "drift@pvv.ntnu.no";
  };
}
