{ fetchgit }:
let
  commit = "cad869fbd95637902673f744581b29e0f3e3f61a";
  project-name = "DeleteBatch";
  tracking-branch = "REL1_41";
in
(fetchgit {
  name = "mediawiki-delete-batch-source";
  url = "https://gerrit.wikimedia.org/r/mediawiki/extensions/${project-name}";
  rev = "refs/heads/${tracking-branch}";
  hash = "sha256-M1ek1WdO1/uTjeYlrk3Tz+nlb/fFZH+O0Ok7b10iKak=";
}).overrideAttrs (_: {
  passthru = { inherit project-name tracking-branch; };
})
