{ pkgs, lib, config, ... }:
let
  format = pkgs.formats.php { };
  cfg = config.services.pvv-nettsiden;
in {
  imports = [
    ./fetch-gallery.nix
  ];

  sops.secrets = lib.genAttrs [
    "nettsiden/door_secret"
    "nettsiden/mysql_password"
    "nettsiden/simplesamlphp/admin_password"
    "nettsiden/simplesamlphp/cookie_salt"
  ] (_: {
    owner = config.services.phpfpm.pools.pvv-nettsiden.user;
    group = config.services.phpfpm.pools.pvv-nettsiden.group;
    restartUnits = [ "phpfpm-pvv-nettsiden.service" ];
  });

  services.idp.sp-remote-metadata = [ "https://${cfg.domainName}/simplesaml/" ];

  services.pvv-nettsiden = {
    enable = true;

    package = pkgs.pvv-nettsiden.override {
      extra_files = {
        "${pkgs.pvv-nettsiden.passthru.simplesamlphpPath}/metadata/saml20-idp-remote.php" = pkgs.writeText "pvv-nettsiden-saml20-idp-remote.php" (import ../idp-simplesamlphp/metadata.php.nix);
        "${pkgs.pvv-nettsiden.passthru.simplesamlphpPath}/config/authsources.php" = pkgs.writeText "pvv-nettsiden-authsources.php" ''
          <?php
          $config = array(
              'admin' => array(
                'core:AdminPassword'
              ),
              'default-sp' => array(
                  'saml:SP',
                  'entityID' => 'https://${cfg.domainName}/simplesaml/',
                  'idp' => 'https://idp.pvv.ntnu.no/',
              ),
          );
	'';
      };
    };

    domainName = "www.pvv.ntnu.no";

    settings = let
      includeFromSops = path: format.lib.mkRaw "file_get_contents('${config.sops.secrets."nettsiden/${path}".path}')";
    in {
      DOOR_SECRET = includeFromSops "door_secret";

      DB = {
        DSN = "mysql:dbname=www-data_nettside;host=mysql.pvv.ntnu.no";
        USER = "www-data_nettsi";
        PASS = includeFromSops "mysql_password";
      };

      # TODO: set up postgres session for simplesamlphp
      SAML = {
        COOKIE_SALT = includeFromSops "simplesamlphp/cookie_salt";
        COOKIE_SECURE = true;
        ADMIN_NAME = "PVV Drift";
        ADMIN_EMAIL = "drift@pvv.ntnu.no";
        ADMIN_PASSWORD = includeFromSops "simplesamlphp/admin_password";
        TRUSTED_DOMAINS = [ cfg.domainName ];
      };
    };
  };

  services.phpfpm.pools."pvv-nettsiden".settings = {
    # "php_admin_value[error_log]" = "stderr";
    "php_admin_flag[log_errors]" = true;
    "catch_workers_output" = true;
  };
}
