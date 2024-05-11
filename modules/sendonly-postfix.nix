{ config, pkgs, lib, ... }:
let
  cfg = config.services.postfix;
in
{
  services.postfix = {
    enable = true;

    hostname = "${config.networking.hostName}.pvv.ntnu.no";
    domain = "pvv.ntnu.no";

    relayHost = "smtp.pvv.ntnu.no";
    relayPort = 465;

    config = {
      smtp_tls_wrappermode = "yes";
      smtp_tls_security_level = "encrypt";
    };

    # Nothing should be delivered to this machine
    destination = [ ];
  };
}
