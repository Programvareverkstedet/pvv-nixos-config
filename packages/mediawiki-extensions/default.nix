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
    commit = "9f19fe510beb671d6ea3076e2e7cbd1025451924";
    hash = "sha256-Bl0evDM4TpsoU5gvZ02UaH5ehFatJcn8YJPbUWRcK9s=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "050d8257c942dfd95b98525c0a61290a89fe8ef4";
    hash = "sha256-3DnY9wlaG9BrnSgt8GMM6fzp3nAAPno49vr2QAz50Ho=";
  })
  (mw-ext {
    name = "DeleteBatch";
    commit = "122072bbfb4eab96ed8c1451a3e74b5557054c58";
    hash = "sha256-L6AXoyFJEZoAQpLO6knJvYtQ6JJPMtaa+WhpnwbJeNU=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "5caf605b9dfdd482cb439d1ba2000cba37f8b018";
    hash = "sha256-TYJqR9ZvaWJ7i1t0XfgUS05qqqCgxAH8tRTklz/Bmlg=";
  })
  (mw-ext {
    name = "Popups";
    commit = "4c22b8604b0dca04f001d9e2bc13b1ea4f934835";
    hash = "sha256-mul9m5zPFSBCfBHZJihJrxP55kFMo/YJ18+JLt5X6zA=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "4a917ed13212f60c33dbc82d3d18c7f5b8461fdc";
    hash = "sha256-3qQgXyPb00V9McN8fxgZlU+MeBzQm5ikH/vkXazibY8=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "d41b4efd3cc44ca3f9f12e35385fc64337873c2a";
    hash = "sha256-wfzXtsEEEjQlW5QE4Rf8pasAW/KSJsLkrez13baxeqA=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "1b02875f3e668fa9033849a663c5f5e450581071";
    hash = "sha256-vQ/o7X7puTN1OQzX3bwKsW3IyVbK1IzvQKV9KtV2kRA=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "0f7b94a0b094edee1c2a9063a3c42a1bdc0282d9";
    hash = "sha256-R406FgNcIip9St1hurtZoPPykRQXBrkJRKA9hapG81I=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "d1917817dd287e7d883e879459d2d2d7bc6966f2";
    hash = "sha256-la3/AQ38DMsrZ2f24T/z3yKzIrbyi3w6FIB5YfxGK9U=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "3cca60141dec1150d3019bd14bd9865cf120362d";
    hash = "sha256-HwbmRVaQObYoJdABeHn19WBoq8aw+Q6QU8xr9YvDcJU=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "d5e6856eeba114fcd1653f3e7ae629989f5ced56";
    hash = "sha256-U5ism/ni9uAxiD4wOVE0/8FFUc4zQCPqYmQ1AL5+E7Q=";
  })
]
