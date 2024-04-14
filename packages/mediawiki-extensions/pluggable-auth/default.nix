{ fetchzip }:
let
  commit = "d5b3ad8f03b65d3746e025cdd7fe3254ad6e4026";
  project-name = "PluggableAuth";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-pluggable-auth-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project_name}/+archive/${commit}.tar.gz";
  hash = "sha256-mLepavgeaNUGYxrrCKVpybGO2ecjc3B5IU8q+gZTx2U=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
