{ config, pkgs, lib, ... }:
{
  security.krb5 = {
    enable = true;
    settings = {
      libdefaults = {
        default_realm = "PVV.NTNU.NO";
        dns_lookup_realm = "yes";
        dns_lookup_kdc = "yes";
      };
      realms."PVV.NTNU.NO".admin_server = "kdc.pvv.ntnu.no";
    };
  };
}
