{ config, ... }:
let
  cfg = config.services.saslauthd;
in
{
  # TODO: This is seemingly required for openldap to authenticate
  #       against kerberos, but I have no idea how to configure it as
  #       such. Does it need a keytab? There's a binary "testsaslauthd"
  #       that follows with `pkgs.cyrus_sasl` that might be useful.
  services.saslauthd = {
    enable = true;
    mechanism = "kerberos5";
    config = ''
      mech_list: gs2-krb5 gssapi
      keytab: /etc/krb5.keytab
    '';
  };

  # TODO: maybe the upstream module should consider doing this?
  environment.systemPackages = [ cfg.package ];
}
