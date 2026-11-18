{ lib
, php
, writeText
, fetchFromGitHub
, extra_files ? { }

}:

php.buildComposerProject rec {
  pname = "simplesamlphp";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "simplesamlphp";
    repo = "simplesamlphp";
    tag = "v${version}";
    hash = "sha256-Md07vWhB/5MDUH+SPQEs8PYiUrkEgAyqQl+LO+ap0Sw=";
  };

  composerStrictValidation = false;

  vendorHash = "sha256-GrEoGJXEyI1Ib+06GIuo5eRwxQ0UMKeX5RswShu2CHM=";

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
