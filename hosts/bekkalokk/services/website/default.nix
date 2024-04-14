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

  services.idp.sp-remote-metadata = [
    "https://www.pvv.ntnu.no/simplesaml/"
    "https://pvv.ntnu.no/simplesaml/"
    "https://www.pvv.org/simplesaml/" 
    "https://pvv.org/simplesaml/" 
  ];

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

  services.nginx.virtualHosts.${cfg.domainName} = {
    serverAliases = [
      "pvv.ntnu.no"
      "www.pvv.org"
      "pvv.org"
    ];

    locations = {
      # Proxy home directories
      "^~ /~" = {
        extraConfig = ''
          proxy_redirect off;
          proxy_pass https://tom.pvv.ntnu.no;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      # Redirect the old webmail/wiki paths from spikkjeposche
      "^~ /webmail".return = "301 https://webmail.pvv.ntnu.no";
      "~ /pvv/([^\\n\\r]*)".return = "301 https://wiki.pvv.ntnu.no/wiki/$1";
      "= /pvv".return = "301 https://wiki.pvv.ntnu.no/";

      # Redirect old wiki entries
      "/disk".return = "301 https://wiki.pvv.ntnu.no/wiki/Diskkjøp";
      "/dok/boker.php".return = "301 https://wiki.pvv.ntnu.no/wiki/Bokhyllen";
      "/styret/lover/".return = "301 https://wiki.pvv.ntnu.no/wiki/Lover";
      "/styret/".return = "301 https://wiki.pvv.ntnu.no/wiki/Styret";
      "/info/".return = "301 https://wiki.pvv.ntnu.no/wiki/";
      "/info/maskinpark/".return = "301 https://wiki.pvv.ntnu.no/wiki/Maskiner";
      "/medlemssider/meldinn.php".return = "301 https://wiki.pvv.ntnu.no/wiki/Medlemskontingent";
      "/diverse/medlems-sider.php".return = "301 https://wiki.pvv.ntnu.no/wiki/Medlemssider";
      "/cert/".return = "301 https://wiki.pvv.ntnu.no/wiki/CERT";
      "/drift".return = "301 https://wiki.pvv.ntnu.no/wiki/Drift";
      "/diverse/abuse.php".return = "301 https://wiki.pvv.ntnu.no/wiki/CERT/Abuse";
      "/nerds/".return = "301 https://wiki.pvv.ntnu.no/wiki/Nerdepizza";

      # Proxy the matrix well-known files
      # Host has be set before proxy_pass
      # The header must be set so nginx on the other side routes it to the right place
      "^~ /.well-known/matrix/" = {
        extraConfig = ''
          proxy_set_header Host matrix.pvv.ntnu.no;
          proxy_pass https://matrix.pvv.ntnu.no/.well-known/matrix/;
        '';
      };
    };
  };
}
