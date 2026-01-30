{ config, lib, fp, pkgs, ... }:
let
  cfg = config.services.snappymail;
in {
  imports = [ (fp /modules/snappymail.nix) ];

  services.snappymail = {
    enable = true;
    hostname = "snappymail.pvv.ntnu.no";
  };

  services.nginx.virtualHosts.${cfg.hostname} = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
  };

  services.rsync-pull-targets = {
    enable = true;
    locations.${cfg.dataDir} = {
      user = "root";
      rrsyncArgs.ro = true;
      authorizedKeysAttrs = [
        "restrict"
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJENMnuNsHEeA91oX+cj7Qpex2defSXP/lxznxCAqV03 snappymail rsync backup";
    };
  };
}
