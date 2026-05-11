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
    commit = "2db9c9cef35d88a0696b926e8e4ea2d479d0d73a";
    hash = "sha256-f0tWJl/4hml+RCp7OoIpQ4WSGKE3/z8DTYOAOHbLA9A=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "b16e614c3c4ba68c346b8dd7393ab005ab127441";
    hash = "sha256-J/TJPo5Oxgpy6UQINivLKl8jzJp4k/mKv6br3kcCSMQ=";
  })
  (mw-ext {
    name = "DeleteBatch";
    commit = "1b947c0f80249cf052b58138f830b379edf080bc";
    hash = "sha256-629RCz+38m2pfyJe/CrYutRoDyN1HzD0KzDdC2wwqlI=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "56893b8ee9ecd03eaee256e08c38bc82657ee0a1";
    hash = "sha256-gvoJey7YLMk+toutQTdWxpaedNDr59E+3xXWmXWCGl0=";
  })
  (mw-ext {
    name = "Popups";
    commit = "6732d8d195bd8312779d8514e92bad372ef63096";
    hash = "sha256-XZzhA9UjAOUMcoGYYwiqRg2uInZ927JOZ9/IrZtarJU=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "fc9658623bd37fad352e326ce81b2a08ef55f04d";
    hash = "sha256-P9WQk8O9qP+vXsBS9A5eXX+bRhnfqHetbkXwU3+c1Vk=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "4c615a9203860bb908f2476a5467573e3287d224";
    hash = "sha256-zNKvzInhdW3B101Hcghk/8m0Y+Qk/7XN7n0i/x/5hSE=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "6884b10e603dce82ee39632f839ee5ccd8a6fbe3";
    hash = "sha256-jcLe3r5fPIrQlp89N+PdIUSC7bkdd7pTmiYppSpdKVQ=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "f0401a6b82528c8fd5a0375f1e55e72d1211f2ab";
    hash = "sha256-tEcCNBz/i9OaE3mNrqw0J2K336BAf6it30TLhQkbtKs=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "6c138ffc65991766fd58ff4739fcb7febf097146";
    hash = "sha256-366Nb0ilmXixWgk5NgCuoxj82Mf0iRu1bC/L/eofAxU=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "9cfcca3195bf88225844f136da90ab7a1f6dd0b9";
    hash = "sha256-jHw3RnUB3bQa1OvmzhEBqadZlFPWH62iGl5BLXi3nZ4=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "fe5329ba7a8c71ac8236cd0e940a64de2645b780";
    hash = "sha256-no6kH7esqKiZv34btidzy2zLd75SBVb8EaYVhfRPQSI=";
  })
]
