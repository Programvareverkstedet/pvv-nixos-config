{ fetchzip }:
let
  commit = "9ae0678d77a9175285a1cfadd5adf28379dbdb3d";
  project-name = "SimpleSAMLphp";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-simple-saml-php-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-s6Uw1fNzGBF0HEMl0LIRLhJkOHugrCE0aTnqawYi/pE=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
