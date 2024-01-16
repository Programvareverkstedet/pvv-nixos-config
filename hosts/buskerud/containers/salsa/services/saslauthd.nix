{ ... }:
{
  # TODO: This is seemingly required for openldap to authenticate
  #       against kerberos, but I have no idea how to configure it as
  #       such. Does it need a keytab? There's a binary "testsaslauthd"
  #       that follows with `pkgs.cyrus_sasl` that might be useful.
  services.saslauthd = {
    enable = true;
    mechanism = "kerberos5";
    # config = ''

    # '';
  };
}
