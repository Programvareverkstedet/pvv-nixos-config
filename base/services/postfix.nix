{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.postfix;
in
{
  services.postfix = {
    enable = true;

    settings.main = {
      myhostname = "${config.networking.hostName}.pvv.ntnu.no";
      mydomain = "pvv.ntnu.no";

      # Nothing should be delivered to this machine
      mydestination = [ ];

      relayhost = [ "smtp.pvv.ntnu.no:465" ];

      smtp_tls_wrappermode = "yes";
      smtp_tls_security_level = "encrypt";
    };
  };
}
