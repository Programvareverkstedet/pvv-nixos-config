{ pkgs, lib, config, values, ... }: let
  cfg = config.services.mediawiki;

  # "mediawiki"
  user = config.systemd.services.mediawiki-init.serviceConfig.User;

  # "mediawiki"
  group = config.users.users.${user}.group;
in {
  sops.secrets = {
    "mediawiki/password" = {
      restartUnits = [ "mediawiki-init.service" "phpfpm-mediawiki.service" ];
      owner = user;
      group = group;
    };
    "keys/postgres/mediawiki" = {
      restartUnits = [ "mediawiki-init.service" "phpfpm-mediawiki.service" ];
      owner = user;
      group = group;
    };
  };

  services.mediawiki = {
    enable = true;
    name = "Programvareverkstedet";
    passwordFile = config.sops.secrets."mediawiki/password".path;
    passwordSender = "drift@pvv.ntnu.no";

    database = {
      type = "postgres";
      host = "postgres.pvv.ntnu.no";
      port = config.services.postgresql.port;
      passwordFile = config.sops.secrets."keys/postgres/mediawiki".path;
      createLocally = false;
      # TODO: create a normal database and copy over old data when the service is production ready
      name = "mediawiki_test";
    };

    # Host through nginx
    webserver = "none";
    poolConfig = let
      listenUser = config.services.nginx.user;
      listenGroup = config.services.nginx.group;
    in {
      inherit user group;
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 4;
      "listen.owner" = listenUser;
      "listen.group" = listenGroup;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = "on";
      "env[PATH]" = lib.makeBinPath [ pkgs.php ];
      "catch_workers_output" = true;
      # to accept *.html file
      "security.limit_extensions" = "";
    };

    extensions = {
      inherit (pkgs.mediawiki-extensions) DeleteBatch UserMerge PluggableAuth SimpleSAMLphp;
    };

    extraConfig = let

      SimpleSAMLphpRepo = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "configuredSimpleSAML";
	version = "2.0.4";
        src = pkgs.fetchzip {
          url = "https://github.com/simplesamlphp/simplesamlphp/releases/download/v${version}/simplesamlphp-${version}.tar.gz";
          sha256 = "sha256-pfMV/VmqqxgtG7Nx4s8MW4tWSaxOkVPtCRJwxV6RDSE=";
        };

	buildPhase = ''
          cat > config/authsources.php << EOF
          <?php
          $config = array(
            'default-sp' => array(
              'saml:SP',
              'idp' => 'https://idp.pvv.ntnu.no/',
            ),
          );
	  EOF
	'';

	installPhase = ''
	  cp -r . $out
	'';
      };

    in ''
      $wgServer = "https://bekkalokk.pvv.ntnu.no";
      $wgLocaltimezone = "Europe/Oslo";

      # Only allow login through SSO
      $wgEnableEmail = false;
      $wgEnableUserEmail = false;
      $wgEmailAuthentication = false;
      $wgGroupPermissions['*']['createaccount'] = false;
      $wgGroupPermissions['*']['autocreateaccount'] = true;
      $wgPluggableAuth_EnableAutoLogin = true;

      # Disable anonymous editing
      $wgGroupPermissions['*']['edit'] = false;

      # Styling
      $wgLogo = "/PNG/PVV-logo.png";
      $wgDefaultSkin = "monobook";

      # Misc
      $wgEmergencyContact = "${cfg.passwordSender}";
      $wgShowIPinHeader = false;
      $wgUseTeX = false;
      $wgLocalInterwiki = $wgSitename;

      # SimpleSAML
      $wgSimpleSAMLphp_InstallDir = "${SimpleSAMLphpRepo}";
      $wgSimpleSAMLphp_AuthSourceId = "default-sp";
      $wgSimpleSAMLphp_RealNameAttribute = "cn";
      $wgSimpleSAMLphp_EmailAttribute = "mail";
      $wgSimpleSAMLphp_UsernameAttribute = "uid";

      # Fix https://github.com/NixOS/nixpkgs/issues/183097
      $wgDBserver = "${toString cfg.database.host}";
    '';
  };

  # Override because of https://github.com/NixOS/nixpkgs/issues/183097
  systemd.services.mediawiki-init.script = let
    # According to module
    stateDir = "/var/lib/mediawiki";
    pkg = cfg.finalPackage;
    mediawikiConfig = config.services.phpfpm.pools.mediawiki.phpEnv.MEDIAWIKI_CONFIG;
    inherit (lib) optionalString mkForce;
  in mkForce ''
    if ! test -e "${stateDir}/secret.key"; then
      tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c 64 > ${stateDir}/secret.key
    fi

    echo "exit( wfGetDB( DB_MASTER )->tableExists( 'user' ) ? 1 : 0 );" | \
    ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/eval.php --conf ${mediawikiConfig} && \
    ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/install.php \
      --confpath /tmp \
      --scriptpath / \
      --dbserver "${cfg.database.host}" \
      --dbport ${toString cfg.database.port} \
      --dbname ${cfg.database.name} \
      ${optionalString (cfg.database.tablePrefix != null) "--dbprefix ${cfg.database.tablePrefix}"} \
      --dbuser ${cfg.database.user} \
      ${optionalString (cfg.database.passwordFile != null) "--dbpassfile ${cfg.database.passwordFile}"} \
      --passfile ${cfg.passwordFile} \
      --dbtype ${cfg.database.type} \
      ${cfg.name} \
      admin

    ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/update.php --conf ${mediawikiConfig} --quick
  '';
}
