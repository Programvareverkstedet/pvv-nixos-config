{ fetchzip }:
let
  commit = "4111a57c34e25bde579cce5d14ea094021e450c8";
  project-name = "PluggableAuth";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-pluggable-auth-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-aPtN8A9gDxLlq2+EloRZBO0DfHtE0E5kbV/adk82jvM=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
