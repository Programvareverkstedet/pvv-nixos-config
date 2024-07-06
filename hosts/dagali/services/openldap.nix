{ config, pkgs, lib, ... }:
{
  services.openldap = let
    dn = "dc=pvv,dc=ntnu,dc=no";
    cfg = config.services.openldap;

    heimdal = config.security.krb5.package;
  in {
    enable = true;

    # NOTE: this is a custom build of openldap with support for
    #       perl and kerberos.
    package = pkgs.openldap.overrideAttrs (prev: {
      # https://github.com/openldap/openldap/blob/master/configure
      configureFlags = prev.configureFlags ++ [
        # Connect to slapd via UNIX socket
        "--enable-local"
        # Cyrus SASL
        "--enable-spasswd"
        # Reverse hostname lookups
        "--enable-rlookups"
        # perl
        "--enable-perl"
      ];

      buildInputs = prev.buildInputs ++ [
        pkgs.perl
	# NOTE: do not upstream this, it might not work with
	#       MIT in the same way
        heimdal
      ];

      extraContribModules = prev.extraContribModules ++ [
        # https://git.openldap.org/openldap/openldap/-/tree/master/contrib/slapd-modules
        "smbk5pwd"
      ];
    });

    settings = {
      attrs = {
        olcLogLevel = [ "stats" "config" "args" ];

        # olcAuthzRegexp = ''
        #   gidNumber=.*\\\+uidNumber=0,cn=peercred,cn=external,cn=auth
        #         "uid=heimdal,${dn2}"
        # '';

        # olcSaslSecProps = "minssf=0";
      };

      children = {
        "cn=schema".includes = let
          # NOTE: needed for smbk5pwd.so module
          schemaToLdif = name: path: pkgs.runCommandNoCC name {
            buildInputs = with pkgs; [ schema2ldif ];
          } ''
            schema2ldif "${path}" > $out
          '';

          hdb-ldif = schemaToLdif "hdb.ldif" "${heimdal.src}/lib/hdb/hdb.schema";
          samba-ldif = schemaToLdif "samba.ldif" "${heimdal.src}/tests/ldap/samba.schema";
        in [
           "${cfg.package}/etc/schema/core.ldif"
           "${cfg.package}/etc/schema/cosine.ldif"
           "${cfg.package}/etc/schema/nis.ldif"
           "${cfg.package}/etc/schema/inetorgperson.ldif"
           "${hdb-ldif}"
           "${samba-ldif}"
        ];

        # NOTE: installation of smbk5pwd.so module
        #       https://git.openldap.org/openldap/openldap/-/tree/master/contrib/slapd-modules/smbk5pwd
        "cn=module{0}".attrs = {
          objectClass = [ "olcModuleList" ];
          olcModuleLoad = [ "${cfg.package}/lib/modules/smbk5pwd.so" ];
        };

        # NOTE: activation of smbk5pwd.so module for {1}mdb
        "olcOverlay={0}smbk5pwd,olcDatabase={1}mdb".attrs = {
          objectClass = [ "olcOverlayConfig" "olcSmbK5PwdConfig" ];
          olcOverlay = "{0}smbk5pwd";
          olcSmbK5PwdEnable = [ "krb5" "samba" ];
          olcSmbK5PwdMustChange = toString (60 * 60 * 24 * 10000);
        };

        "olcDatabase={1}mdb".attrs = {
          objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];

          olcDatabase = "{1}mdb";

          olcSuffix = dn;

          # TODO: PW is supposed to be a secret, but it's probably fine for testing
          olcRootDN = "cn=users,${dn}";

          # TODO: replace with proper secret
          olcRootPW.path = pkgs.writeText "olcRootPW" "pass";

          olcDbDirectory = "/var/lib/openldap/test-smbk5pwd-db";
          olcDbIndex = "objectClass eq";

          olcAccess = [
            ''{0}to attrs=userPassword,shadowLastChange
                by dn.exact=cn=users,${dn} write
                by self write
                by anonymous auth
                by * none''

            ''{1}to dn.base=""
                by * read''

            /* allow read on anything else */
            # ''{2}to *
            #     by cn=users,${dn} write by dn.exact=gidNumber=0+uidNumber=0+cn=peercred,cn=external write
            #     by * read''
          ];
        };
      };
    };
  };
}
