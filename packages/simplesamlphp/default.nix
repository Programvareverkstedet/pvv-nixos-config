{ lib
, php
, writeText
, fetchFromGitHub
, extra_files ? { }

}:

php.buildComposerProject rec {
  pname = "simplesamlphp";
  version = "2.4.3";

  src = fetchFromGitHub {
    owner = "simplesamlphp";
    repo = "simplesamlphp";
    tag = "v${version}";
    hash = "sha256-vv4gzcnPfMapd8gER2Vsng1SBloHKWrJJltnw2HUnX4=";
  };

  composerStrictValidation = false;

  vendorHash = "sha256-vu3Iz6fRk3Gnh9Psn46jgRYKkmqGte+5xHBRmvdgKG4=";

  # TODO: metadata could be fetched automagically with these:
  #   - https://simplesamlphp.org/docs/contrib_modules/metarefresh/simplesamlphp-automated_metadata.html
  #   - https://idp.pvv.ntnu.no/simplesaml/saml2/idp/metadata.php
  postPatch = lib.pipe extra_files [
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
