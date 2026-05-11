{ config, lib, ... }:
{
  services.postfix.enable = lib.mkForce false;

  services.nullmailer = {
    enable = true;
    config = {
      me = config.networking.fqdn;
      remotes = "mail.pvv.ntnu.no smtp --port=25";
    };
  };
}
