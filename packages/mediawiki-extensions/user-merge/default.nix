{ fetchzip }:
let
  commit = "c17c919bdb9b67bb69f80df43e9ee9d33b1ecf1b";
  project-name = "UserMerge";
  tracking-branch = "REL1_41";
in
fetchzip {
  name = "mediawiki-user-merge-source";
  url = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/${project-name}/+archive/${commit}.tar.gz";
  hash = "sha256-+mkzTCo8RVlGoFyfCrSb5YMh4J6Pbi1PZLFu5ps8bWY=";
  stripRoot = false;
  passthru = { inherit project-name tracking-branch; };
}
