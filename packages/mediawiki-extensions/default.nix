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
    commit = "6e5b06e8cf2d040c0abb53ac3735f9f3c96a7a4f";
    hash = "sha256-Jee+Ws9REUohywhbuemixXKaTRc54+cIlyUNDCyYcEM=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "da9c5d4f03e6425f6f2cf68b75d21311e0f7e77e";
    hash = "sha256-aL+v9xeqKHGmQVUWVczh54BkReu+fP49PT1NP7eTC6k=";
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
    commit = "7ed940a09f83f869cbc0bc20f3ca92f85b534951";
    hash = "sha256-pcDPcu4kSvMHfSOuShrod694TKI9Oo3AEpMP9DXp9oY=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "e755852a8e28a030a21ded2d5dd7270eb933b683";
    hash = "sha256-zyI5nSE+KuodJOWyV0CQM7G0GfkKEgfoF/czi2/qk98=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "d41b4efd3cc44ca3f9f12e35385fc64337873c2a";
    hash = "sha256-wfzXtsEEEjQlW5QE4Rf8pasAW/KSJsLkrez13baxeqA=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "fd7cf4d95a70ef564130266f2a6b18f33a2a2ff9";
    hash = "sha256-5OhDPFhIi55Eh5+ovMP1QTjNBb9Sm/3vyArNCApAgSw=";
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
    commit = "032364cfdff33818e6ae0dfa251fe3973b0ae4f3";
    hash = "sha256-AQDdq9r6rSo8h4u1ERonH14/1i1BgLGdzANEiQ065PU=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "cb9f7e06a9c59b6d3b31c653e5886b7f53583d01";
    hash = "sha256-UWi3Ac+LCOLliLkXnS8YL0rD/HguuPH5MseqOm0z7s4=";
  })
]
