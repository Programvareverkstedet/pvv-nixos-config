{ config, pkgs, lib, ... }:
let

  realm = "PVV.NTNU.NO";

  cfg = config.security.krb5;
in
{
  security.krb5 = {
    enable = true;

    # NOTE: This has a small edit that moves an include header to $dev/include.
    #       It is required in order to build smbk5pwd, because of some nested includes.
    #       We should open an issue upstream (heimdal, not nixpkgs), but this patch
    #       will do for now.
    # package = pkgs.callPackage ./package.nix {
    #   inherit (pkgs.apple_sdk.frameworks)
    #     CoreFoundation Security SystemConfiguration;
    # };
    package = pkgs.heimdal.overrideAttrs (prev: {
      postInstall = prev.postInstall + ''
        cp include/heim_threads.h $dev/include
      '';
    });

    settings = {
      # logging.kdc = "CONSOLE";
      realms.${realm} = {
        admin_server = "dagali.pvv.ntnu.no";
        kdc = [ "localhost" ];
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
      };

      domain_realm = {
        "pvv.ntnu.no" = realm;
        ".pvv.ntnu.no" = realm;
      };

      logging = {
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
        dbname = "/var/heimdal/heimdal";
        mkey = "/var/heimdal/mkey";
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
}
