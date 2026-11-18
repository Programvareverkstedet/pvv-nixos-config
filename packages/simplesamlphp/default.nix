{ lib
, php
, writeText
, fetchFromGitHub
, extra_files ? { }

}:

php.buildComposerProject rec {
  pname = "simplesamlphp";
  version = "2.5.4";

  src = fetchFromGitHub {
    owner = "simplesamlphp";
    repo = "simplesamlphp";
    tag = "v${version}";
    hash = "sha256-99zWcwamT7xJardb+mXSZ9JS57O/wy9P03cx0AKVFT8=";
  };

  composerStrictValidation = false;

  vendorHash = "sha256-7S3DK6n6t178udvobQ1HbCaSeaTvrdAEKYKD2vAj4wc=";

  # TODO: metadata could be fetched automagically with these:
  #   - https://simplesamlphp.org/docs/contrib_modules/metarefresh/simplesamlphp-automated_metadata.html
  #   - https://idp.pvv.ntnu.no/simplesaml/saml2/idp/metadata.php
  postPatch = let
    fileFromEnv = name: ''
      $file = getenv('${name}');
      if ($file === false || $file === ''') {
          throw new \SimpleSAML\Error\ConfigurationError('The environment variable ${name} is not set.');
      }
    '';

    wrappers = {
      "config/config.php" = writeText "simplesamlphp-config.php" ''
        <?php
        ${fileFromEnv "SIMPLESAMLPHP_CONFIG_OVERRIDES_FILE"}
        require __DIR__ . '/config.php.dist';
        return array_replace($config, require $file);
      '';

      "config/authsources.php" = writeText "simplesamlphp-authsources.php" ''
        <?php
        ${fileFromEnv "SIMPLESAMLPHP_AUTHSOURCES_FILE"}
        return require $file;
      '';
    };
  in lib.pipe (wrappers // extra_files) [
    (lib.mapAttrsToList (target_path: source_path: ''
      mkdir -p $(dirname "${target_path}")
      cp -r "${source_path}" "${target_path}"
    ''))
    lib.concatLines
  ];

  postInstall = ''
    ln -sr $out/share/php/simplesamlphp/vendor/simplesamlphp/simplesamlphp-assets-base $out/share/php/simplesamlphp/public/assets/base
  '';
}
