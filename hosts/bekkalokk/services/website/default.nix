{ pkgs, lib, config, ... }:
let
  format = pkgs.formats.php { };
  cfg = config.services.pvv-nettsiden;
in {
  imports = [
    ./fetch-gallery.nix
  ];

  services.idp.sp-remote-metadata = [ "https://www2.pvv.ntnu.no/simplesaml/" ];

  services.pvv-nettsiden = {
    enable = true;

    package = pkgs.pvv-nettsiden.override {
      extra_files = {
        "${pkgs.pvv-nettsiden.passthru.simplesamlphpPath}/metadata/saml20-idp-remote.php" = pkgs.writeText "pvv-nettsiden-saml20-idp-remote.php" (import ../idp-simplesamlphp/metadata.php.nix);
        "${pkgs.pvv-nettsiden.passthru.simplesamlphpPath}/config/authsources.php" = pkgs.writeText "pvv-nettsiden-authsources.php" ''
          <?php
          $config = array(
              # 'admin' => array(
              #   'core:AdminPassword'
              # ),
              'default-sp' => array(
                  'saml:SP',
                  'entityID' => 'https://www2.pvv.ntnu.no/simplesaml/',
                  'idp' => 'https://idp2.pvv.ntnu.no/',
              ),
          );
	'';
      };
    };

    domainName = "www2.pvv.ntnu.no";

    settings = {
      DOOR_SECRET = "verysecret";

      DB = {
        DSN = "mysql:dbname=www_data_www2;host=mysql.pvv.ntnu.no";
        USER = "www-data_www2";
        PASS = format.lib.mkRaw "file_get_contents('${config.sops.secrets."nettsiden/database/password".path}')";
      };

      SAML = {
        COOKIE_SALT = "changeme";
        COOKIE_SECURE = true;
        ADMIN_NAME = "PVV Drift";
        ADMIN_EMAIL = "drift@pvv.ntnu.no";
        ADMIN_PASSWORD = "torskefjes";
        TRUSTED_DOMAINS = [ cfg.domainName ];
      };
    };
  };

  services.phpfpm.pools."pvv-nettsiden".settings = {
    # "php_admin_value[error_log]" = "stderr";
    "php_admin_flag[log_errors]" = true;
    "catch_workers_output" = true;
  };

  sops.secrets."nettsiden/database/password" = {
    owner = config.services.phpfpm.pools.pvv-nettsiden.user;
    group = config.services.phpfpm.pools.pvv-nettsiden.group;
  };
}
