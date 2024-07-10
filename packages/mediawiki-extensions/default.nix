{ pkgs, lib }:
let
  kebab-case-name = project-name: lib.pipe project-name [
    (builtins.replaceStrings
      lib.upperChars
      (map (x: "-${x}") lib.lowerChars)
    )
    (lib.removePrefix "-")
  ];

  mw-ext = {
    name
  , commit
  , hash
  , tracking-branch ? "REL1_41"
  , kebab-name ? kebab-case-name name
  , fetchgit ? pkgs.fetchgit
  }:
  {
    ${name} = (fetchgit {
      name = "mediawiki-${kebab-name}-source";
      url = "https://gerrit.wikimedia.org/r/mediawiki/extensions/${name}";
      rev = commit;
      inherit hash;
    }).overrideAttrs (_: {
      passthru = { inherit name kebab-name tracking-branch; };
    });
  };
in
# NOTE: to add another extension, you can add an mw-ext expression
#       with an empty (or even wrong) commit and empty hash, and
#       run the update script
lib.mergeAttrsList [
  (mw-ext {
    name = "DeleteBatch";
    commit = "cad869fbd95637902673f744581b29e0f3e3f61a";
    hash = "sha256-M1ek1WdO1/uTjeYlrk3Tz+nlb/fFZH+O0Ok7b10iKak=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "4111a57c34e25bde579cce5d14ea094021e450c8";
    hash = "sha256-aPtN8A9gDxLlq2+EloRZBO0DfHtE0E5kbV/adk82jvM=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "ecb47191fecd1e0dc4c9d8b90a9118e393d82c23";
    hash = "sha256-gKu+O49XrAVt6hXdt36Ru7snjsKX6g2CYJ0kk/d+CI8=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "c17c919bdb9b67bb69f80df43e9ee9d33b1ecf1b";
    hash = "sha256-+mkzTCo8RVlGoFyfCrSb5YMh4J6Pbi1PZLFu5ps8bWY=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "90bb3d455892e25317029ffd4bda93159e8faac8";
    hash = "sha256-SZAVELQUKZtwSM6NVlxvIHdFPodko8fhZ/uwB0LCFDA=";
  })
]
