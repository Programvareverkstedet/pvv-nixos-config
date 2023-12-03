{ config, pkgs, values, lib, ... }:
{
  containers.bikkje = {
    autoStart = true;
    interfaces = [ "enp4s0f0" ];

    config = { config, pkgs, ... }: {
      imports = [
        ../../modules/home-areas.nix
      ];

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
          #(with python3Packages; [
          #  numpy
          #  requests
          #])
          ruby
          tcl
      ];

      services.openssh = {
        enable = true;
        ports = [ 22 80 443 ];
        openFirewall = true;
        extraConfig = ''
          PubkeyAcceptedAlgorithms=+ssh-rsa
       '';

        settings.GatewayPorts = "yes";
        banner = builtins.readFile ../../motd;
      };

      networking = {
        firewall.enable = true;
        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;
        hostName = "bikkje";
      };

      systemd.network.enable = true;
      systemd.network.networks."30-enp4s0f0" = values.defaultNetworkConfig // {
        matchConfig.Name = "enp4s0f0";
        address = with values.hosts.bikkje; [ (ipv4 + "/25") (ipv6 + "/64") ];
      };
      
      system.stateVersion = "23.11";
      services.resolved.enable = true;
    };
  };

  # TODO
  # - Kerberos Authentication
  # - Mail Transfer Agent
}
