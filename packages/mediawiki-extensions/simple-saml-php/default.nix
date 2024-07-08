{ fetchzip }:
let
  commit = "ecb47191fecd1e0dc4c9d8b90a9118e393d82c23";
  project-name = "SimpleSAMLphp";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-simple-saml-php-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-gKu+O49XrAVt6hXdt36Ru7snjsKX6g2CYJ0kk/d+CI8=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
