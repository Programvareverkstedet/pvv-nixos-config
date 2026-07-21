{ config, lib, ... }:
{
  services.nullmailer = {
    enable = true;

    config = {
      adminaddr = "root@pvv.ntnu.no";
      defaultdomain = "pvv.ntnu.no";
      defaulthost = "pvv.ntnu.no";

      me = lib.mkDefault config.networking.fqdn;
      remotes = lib.mkDefault "smtp.pvv.ntnu.no smtp port=465 tls";
    };
  };
}
