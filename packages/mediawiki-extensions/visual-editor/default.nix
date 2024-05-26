{ fetchzip }:
let
  commit = "bb92d4b0bb81cebd73a3dbabfb497213dac349f2";
  project-name = "VisualEditor";
  tracking-branch = "REL1_40";
in
fetchzip {
  name = "mediawiki-visual-editor-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-lShpSoR+NLfdd5i7soM6J40pq+MzCMG0M1tSYsS+jAg=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
