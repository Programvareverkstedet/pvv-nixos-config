{
  lib,
  config,
  pkgs,
  values,
  ...
}:
{
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "ens3";
    # Lazy IPv6 connectivity for the container
    enableIPv6 = true;
  };

  containers.bikkje = {
    autoStart = true;
    config =
      { config, pkgs, ... }:
      {
        #import packages
        packages = with pkgs; [
          alpine
          mutt
          mutt-ics
          mutt-wizard
          weechat
          weechatScripts.edit
          hexchat
          irssi
          pidgin
        ];

        networking = {
          hostName = "bikkje";
          firewall = {
            enable = true;
            # Allow SSH and HTTP and ports for email and irc
            allowedTCPPorts = [
              80
              22
              194
              994
              6665
              6666
              6667
              6668
              6669
              6697
              995
              993
              25
              465
              587
              110
              143
              993
              995
            ];
            allowedUDPPorts = [
              80
              22
              194
              994
              6665
              6666
              6667
              6668
              6669
              6697
              995
              993
              25
              465
              587
              110
              143
              993
              995
            ];
          };
          # Use systemd-resolved inside the container
          # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
          useHostResolvConf = lib.mkForce false;
        };

        services.resolved.enable = true;

        # Don't change (even during upgrades) unless you know what you are doing.
        # See https://search.nixos.org/options?show=system.stateVersion
        system.stateVersion = "23.11";
      };
  };
}
