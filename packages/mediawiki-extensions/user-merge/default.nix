{ fetchzip }:
let
  commit = "a53af3b8269ed19ede3cf1fa811e7ec8cb00af92";
  project-name = "UserMerge";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-user-merge-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-0ofCZhhv4aVTGq469Fdu7k0oVQu3kG3HFa8zaBbUr/M=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
