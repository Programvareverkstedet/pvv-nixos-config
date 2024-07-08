{ fetchzip }:
let
  commit = "170d19aad1f28dc6bd3f98ee277680cabba9db0c";
  project-name = "VisualEditor";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-visual-editor-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-Qg5AE1kQ+R4iNYyqzjrcOf3g6WnPSQcYow1tU0RwFk0=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
