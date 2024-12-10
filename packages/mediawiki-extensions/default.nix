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
  , tracking-branch ? "REL1_42"
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
    commit = "9f69f2cf7616342d236726608a702d651b611938";
    hash = "sha256-sRaYj34+7aghJUw18RoowzEiMx0aOANU1a7YT8jivBw=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "1a1048c770795789676adcf8a33c1b69f6f5d3ae";
    hash = "sha256-Y5ePrtLNiko2uU/sesm8jdYmxZkYzQDHfkIG1Q0v47I=";
  })
  (mw-ext {
    name = "DeleteBatch";
    commit = "b76bb482e026453079104d00f9675b4ab851947e";
    hash = "sha256-GebF9B3RVwpPw8CYKDDT6zHv/MrrzV6h2TEIvNlRmcw=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "1da98f447fd8321316d4286d8106953a6665f1cc";
    hash = "sha256-DKDVcAfWL90FmZbSsdx1J5PkGu47EsDQmjlCpcgLCn4=";
  })
  (mw-ext {
    name = "Popups";
    commit = "9b9e986316b9662b1b45ce307a58dd0320dd33cf";
    hash = "sha256-rSOZHT3yFIxA3tPhIvztwMSmSef/XHKmNfQl1JtGrUA=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "eb6a987e90db47b09b0454fd06cddb69fdde9c40";
    hash = "sha256-Nr0ZLIrS5jnpiBgGnd90lzi6KshcsxeC+xGmNsB/g88=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "fd4d49cf48d16efdb91ae8128cdd507efe84d311";
    hash = "sha256-Qdtroew2j3AsZYlhAAUKQXXS2kUzUeQFnuR6ZHdFhAQ=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "836e3ca277301addd2578b2e746498ff6eb8e574";
    hash = "sha256-UMcRLYxYn+AormwTYjKjjZZjA806goMY2TRQ4KoS5fY=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "06a2587689eba0a17945fd9bd4bb61674d3a7853";
    hash = "sha256-C7j0jCkMeVZiLKpk+55X+lLnbG4aeH+hWIm3P5fF4fw=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "41759d0c61377074d159f7d84130a095822bc7a3";
    hash = "sha256-pGjA7r30StRw4ff0QzzZYUhgD3dC3ZuiidoSEz8kA8Q=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "a128b11fe109aa882de5a40d2be0cdd0947ab11b";
    hash = "sha256-bv1TkomouOxe+DKzthyLyppdEUFSXJ9uE0zsteVU+D4=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "21383e39a4c9169000acd03edfbbeec4451d7974";
    hash = "sha256-aPVpE6e4qLLliN9U5TA36e8tFrIt7Fl8RT1cGPUWoNI=";
  })
]
