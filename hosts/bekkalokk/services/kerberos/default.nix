{ config, pkgs, lib, ... }:
{
  #######################
  # TODO: remove these once nixos 24.05 gets released
  #######################
  # imports = [
  #   ./krb5.nix
  #   ./pam.nix
  # ];
  # disabledModules = [
  #   "config/krb5/default.nix"
  #   "security/pam.nix"
  # ];
  #######################

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
