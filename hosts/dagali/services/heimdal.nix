{ config, pkgs, lib, ... }:
let
  realm = "PVV.LOCAL";
  cfg = config.security.krb5;
in
{
  security.krb5 = {
    enable = true;

    # NOTE: This is required in order to build smbk5pwd, because of some nested includes.
    #       We should open an issue upstream (heimdal, not nixpkgs), but this patch
    #       will do for now.
    package = pkgs.heimdal.overrideAttrs (prev: {
      postInstall = prev.postInstall + ''
        cp include/heim_threads.h $dev/include
      '';
    });

    settings = {
      realms.${realm} = {
        kdc = [ "dagali.${lib.toLower realm}" ];
        admin_server = "dagali.${lib.toLower realm}";
        kpasswd_server = "dagali.${lib.toLower realm}";
        default_domain = lib.toLower realm;
        primary_kdc = "dagali.${lib.toLower realm}";
      };

      kadmin.default_keys = lib.concatStringsSep " " [
        "aes256-cts-hmac-sha1-96:pw-salt"
        "aes128-cts-hmac-sha1-96:pw-salt"
      ];

      libdefaults.default_etypes = lib.concatStringsSep " " [
        "aes256-cts-hmac-sha1-96"
        "aes128-cts-hmac-sha1-96"
      ];

      libdefaults = {
        default_realm = realm;
        dns_lookup_kdc = false;
        dns_lookup_realm = false;
      };

      domain_realm = {
        "${lib.toLower realm}" = realm;
        ".${lib.toLower realm}" = realm;
      };

      logging = {
        # kdc = "CONSOLE";
        kdc = "SYSLOG:DEBUG:AUTH";
        admin_server = "SYSLOG:DEBUG:AUTH";
        default = "SYSLOG:DEBUG:AUTH";
      };
    };
  };

  services.kerberos_server = {
    enable = true;
    settings = {
      realms.${realm} = {
        dbname = "/var/lib/heimdal/heimdal";
        mkey = "/var/lib/heimdal/m-key";
        acl = [
          {
            principal = "kadmin/admin";
            access = "all";
          }
          {
            principal = "felixalb/admin";
            access = "all";
          }
          {
            principal = "oysteikt/admin";
            access = "all";
          }
        ];
      };
      # kadmin.default_keys = lib.concatStringsSep " " [
      #   "aes256-cts-hmac-sha1-96:pw-salt"
      #   "aes128-cts-hmac-sha1-96:pw-salt"
      # ];

      # libdefaults.default_etypes = lib.concatStringsSep " " [
      #   "aes256-cts-hmac-sha1-96"
      #   "aes128-cts-hmac-sha1-96"
      # ];

      # password_quality.min_length = 8;
    };
  };

  networking.firewall.allowedTCPPorts = [ 88 464 749 ];
  networking.firewall.allowedUDPPorts = [ 88 464 749 ];

  networking.hosts = {
    "127.0.0.2" = lib.mkForce [ ];
    "::1" = lib.mkForce [ ];
  };
}
