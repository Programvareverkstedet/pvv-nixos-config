{ lib
, php
, writeText
, fetchFromGitHub
, extra_files ? { }

}:

php.buildComposerProject rec {
  pname = "simplesamlphp";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "simplesamlphp";
    repo = "simplesamlphp";
    rev = "v${version}";
    hash = "sha256-jo7xma60M4VZgeDgyFumvJp1Sm+RP4XaugDkttQVB+k=";
  };

  composerStrictValidation = false;

  vendorHash = "sha256-n6lJ/Fb6xI124PkKJMbJBDiuISlukWQcHl043uHoBb4=";

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
