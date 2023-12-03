{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    heimdal
  ];

  security.pam.krb5.enable = true;

  environment.etc."krb5.conf".text = ''
    [libdefaults]
      default_realm = PVV.NTNU.NO
      dns_lookup_realm = yes
      dns_lookup_kdc = yes

    [appdefaults]
      pam = {
        ignore_k5login = yes
      }

    [realms]
      PVV.NTNU.NO = {
        admin_server = kdc.pvv.ntnu.no
      }
  '';
}
