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
  , tracking-branch ? "REL1_45"
  , kebab-name ? kebab-case-name name
  , fetchgit ? pkgs.fetchgit
  , url ? "https://gerrit.wikimedia.org/r/mediawiki/extensions/${name}"
  }:
  {
    ${name} = (fetchgit {
      name = "mediawiki-${kebab-name}-source";
      rev = commit;
      inherit url;
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
    commit = "af7e82f24ba4b68393712fece6f1b5fa4bb049ec";
    hash = "sha256-XT8E4O6MEZYHSs6Q+A/dfYaUvJ4kY13Kd/cq30dA5NA=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "7ab826eff8c4097589a3199c40c507717af23234";
    hash = "sha256-kMIyGW9J4OSGSetByel7hEGgxPRJmQ53it6ndpYA/Hs=";
  })
  (mw-ext {
    name = "DeleteBatch";
    commit = "b5920283cfe78b86a63a1037a81651c58ce764da";
    hash = "sha256-LwuVX2s5Q4uc6o7hlTjFzRTwvSCwTk74gBpX0HoLDMA=";
  })
  (mw-ext {
    name = "PdfHandler";
    commit = "dc1a3ca04ac6ec7d7de7ce5355803510508a2575";
    hash = "sha256-ltAQZtfTMMLRPATA7rclSNW8Yz4ctGc30CxlL3SRBWU=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "4b57a23e32d72bd3f74184ff2734aa483a5b0c63";
    hash = "sha256-ZGw0Wgz0Sg04YDcOzkOGywmfQ6s6Ex17QbjmUDO1D8c=";
  })
  (mw-ext {
    name = "Popups";
    commit = "f74a8639f57232898978d9f3792293eb2d370e40";
    hash = "sha256-uunUtN3M/ksW/kcbeIzDVTdb1P/PHTeTwaTsvspMLko=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "35c85c96167922adc98e62dd6573789d906dd7d7";
    hash = "sha256-FEWADJW53cDOlLseM62VL66PENv/jNnwuCMo2Pb02ek=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "70778bb02f972abbb51e6ba3e0f6545b00dcab00";
    hash = "sha256-wfmFJKy+ih84qFM9DVcCQFAZBx45s7Hl0lRnseMPhGY=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "cca3b3430067f2161bf65de822f70dd38fe07bba";
    hash = "sha256-OxLwiF8FlWizkpDF9GXYfjehKtrltX8ihiCE+fNJpgw=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "101a159dd0190759a16551a86800144c18b6ff5c";
    hash = "sha256-IGQQVAx8/76ivHq9b97ec1AlFoqbRl7uhXhwoFimsG4=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "6c0d105e07538c34bfde989bd26fa1945f8d1b79";
    hash = "sha256-w058Ihk0I98hIG1tkVJGy1bzbv7XXyUksGexXgCN540=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "8d8c6d7f179a5f799e1fa8cba207d81f58f722d2";
    hash = "sha256-wbYHXi2vD521EMzUl7ttinG4YdLv/DwYvVUew7dka0g=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "f53000f0499858fe74e4f5008b2f5e467d9d9382";
    hash = "sha256-+HTXZEVCwMD8z6c1kCZA3k686HzNd30pJljzRvf+gMg=";
  })

  (mw-ext {
    name = "MediawikiMatrixNotifs";
    commit = "52d2a46c03f51af7c16ed4d7b3b07b0cbbffb4df";
    hash = "sha256-AADWunm2Rn2cfxeu9xyYBw5txnaIbJNdR3jxLqgzAy8=";
    url = "https://git.pvv.ntnu.no/oysteikt/mediawiki-matrix-notifs.git";
    tracking-branch = "master";
  })
]
