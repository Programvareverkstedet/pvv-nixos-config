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
  , tracking-branch ? "REL1_44"
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
    commit = "83e1d0c13f34746f0d7049e38b00e9ab0a47c23f";
    hash = "sha256-qH9fSQZGA+z6tBSh1DaTKLcujqA6K/vQmZML9w5X8mU=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "af2b08b9ad2b89a64b2626cf80b026c5b45e9922";
    hash = "sha256-CxXPwCKUlF9Tg4JhwLaKQyvt43owq75jCugVtb3VX+I=";
  })
  (mw-ext {
    name = "DeleteBatch";
    commit = "3d6f2fd0e3efdae1087dd0cc8b1f96fe0edf734f";
    hash = "sha256-iD9EjDIW7AGpZan74SIRcr54dV8W7xMKIDjatjdVkKs=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "85e96acd1ac0ebcdaa29c20eae721767a938f426";
    hash = "sha256-bMVhrg8FsfWhXF605Cj5TgI0A6Jy/MIQ5aaUcLQQ0Ss=";
  })
  (mw-ext {
    name = "Popups";
    commit = "410e2343c32a7b18dcdc2bbd995b0bfdf3bf5f37";
    hash = "sha256-u2AlR75x54rCpiK9Mz00D9odJCn8fmi6DRU4QKmKqSc=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "904f323f343dba5ff6a6cdd143c4a8ef5b7d2c55";
    hash = "sha256-ZOVYhjMMyWbqwZOBb39hMIRmzzCPEnz2y8Q2jgyeERw=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "a2f77374713473d594e368de24539aebcc1a800a";
    hash = "sha256-5+t3VQFKcrIffDNPJ4RWBIWS6K1gTOcEleYWmM6xWms=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "76a6a04bd13a606923847ba68750b5d98372cacd";
    hash = "sha256-X2+U5PMqzkSljw2ypIvJUSaPDaonTkQx89OgKzf5scw=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "7de60a8da6576d7930f293d19ef83529abf52704";
    hash = "sha256-iPmFDoO5V4964CVyd1mBSQcNlW34odbvpm2CfDBlPBU=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "71eb53ff4289ac4efaa31685ab8b6483c165a584";
    hash = "sha256-OfKSEPgctfr659oh5jf99T0Rzqn+60JhNaZq+2gfubk=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "a6a63f53605c4d596c3df1dcc2583ffd3eb8d929";
    hash = "sha256-4d8picO66uzKoxh1TdyvKLHebc6ZL7N2DdXLV2vgBL4=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "0a5719bb95326123dd0fee1f88658358321ed7be";
    hash = "sha256-eQMyjhdm1E6TkktIHad1NMeMo8QNoO8z4A05FYOMCwQ=";
  })
]
