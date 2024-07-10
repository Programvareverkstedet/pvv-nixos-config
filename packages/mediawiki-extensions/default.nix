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
    name = "CodeEditor";
    commit = "7d8447035e381d76387e38b92e4d1e2b8d373a01";
    hash = "sha256-v2AlbP0vZma3qZyEAWGjZ/rLcvOpIMroyc1EixKjlAU=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "a7b4541089f9b88a0b722d9d790e4cf0f13aa328";
    hash = "sha256-clyzN3v3+J4GjdyhrCsytBrH7VR1tq5yd0rB+32eWCg=";
  })
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
    name = "Popups";
    commit = "f1bcadbd8b868f32ed189feff232c47966c2c49e";
    hash = "sha256-PQAjq/X4ZYwnnZ6ADCp3uGWMIucJy0ZXxsTTbAyxlSE=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "7b99c95f588b06635ee3c487080d6cb04617d4b5";
    hash = "sha256-pviueRHQAsSlv4AtnUpo2Cjci7CbJ5aM75taEXY+WrI=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "ecb47191fecd1e0dc4c9d8b90a9118e393d82c23";
    hash = "sha256-gKu+O49XrAVt6hXdt36Ru7snjsKX6g2CYJ0kk/d+CI8=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "1ec66ce80f8a4322138efa56864502d0ee069bad";
    hash = "sha256-Lv3Lq9dYAtdgWcwelveTuOhkP38MTu0m5kmW8+ltRis=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "581180e898d6a942e2a65c8f13435a5d50fffa67";
    hash = "sha256-zW8O0mzG4jYfQoKi2KzsP+8iwRCLnWgH7qfmDE2R+HU=";
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
  (mw-ext {
    name = "WikiEditor";
    commit = "8dba5b13246d7ae09193f87e6273432b3264de5f";
    hash = "sha256-vF9PBuM+VfOIs/a2X1JcPn6WH4GqP/vUJDFkfXzWyFU=";
  })
]
