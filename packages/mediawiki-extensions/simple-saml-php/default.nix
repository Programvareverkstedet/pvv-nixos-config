{ fetchgit }:
let
  commit = "ecb47191fecd1e0dc4c9d8b90a9118e393d82c23";
  project-name = "SimpleSAMLphp";
  tracking-branch = "REL1_41";
in
(fetchgit {
  name = "mediawiki-simple-saml-php-source";
  url = "https://gerrit.wikimedia.org/r/mediawiki/extensions/${project-name}";
  rev = "refs/heads/${tracking-branch}";
  hash = "sha256-gKu+O49XrAVt6hXdt36Ru7snjsKX6g2CYJ0kk/d+CI8=";
}).overrideAttrs (_: {
  passthru = { inherit project-name tracking-branch; };
})
