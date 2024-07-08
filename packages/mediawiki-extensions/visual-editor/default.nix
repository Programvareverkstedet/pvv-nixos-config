{ fetchgit }:
let
  commit = "170d19aad1f28dc6bd3f98ee277680cabba9db0c";
  project-name = "VisualEditor";
  tracking-branch = "REL1_41";
in
(fetchgit {
  name = "mediawiki-visual-editor-source";
  url = "https://gerrit.wikimedia.org/r/mediawiki/extensions/${project-name}";
  rev = "refs/heads/${tracking-branch}";
  hash = "sha256-5WVlO/OEk4eln5j/w4Tu/MXSmlvjIn7l6H+OTPaV+t4=";
}).overrideAttrs (_: {
  passthru = { inherit project-name tracking-branch; };
})
