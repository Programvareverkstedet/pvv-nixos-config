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
    commit = "af7e82f24ba4b68393712fece6f1b5fa4bb049ec";
    hash = "sha256-XT8E4O6MEZYHSs6Q+A/dfYaUvJ4kY13Kd/cq30dA5NA=";
  })
  (mw-ext {
    name = "CodeMirror";
    commit = "f06dfd40a08562a841ddf11b4ae3444ef06c98c7";
    hash = "sha256-5zXkBjOwFdoQezkPRJ2AcBZLZEEpGG6FawO2K3KzllI=";
  })
  (mw-ext {
    name = "DeleteBatch";
    commit = "9bc75a753efefedfc88c598fb01f18a7e4b61f00";
    hash = "sha256-1xA758fsvoioN9xuq0hRqZKtPXMQViVLtuRINDtowdk=";
  })
  (mw-ext {
    name = "PluggableAuth";
    commit = "64133683b73d8eeea8069fe7ed9cb7237fd5c212";
    hash = "sha256-wqpfgVLenZp6XC510nrsrbvK1IMEPcWVYq5YuAOt5+c=";
  })
  (mw-ext {
    name = "Popups";
    commit = "f74a8639f57232898978d9f3792293eb2d370e40";
    hash = "sha256-uunUtN3M/ksW/kcbeIzDVTdb1P/PHTeTwaTsvspMLko=";
  })
  (mw-ext {
    name = "Scribunto";
    commit = "cbab0c740e03c8e6184fd647d95e24e0826d20cb";
    hash = "sha256-vXS3+wrUBVtPsETa19pMvud9sALGt4Ao9mM5rQRbBQc=";
  })
  (mw-ext {
    name = "SimpleSAMLphp";
    kebab-name = "simple-saml-php";
    commit = "fc5ad4501434fe85198f0b1f0087d798efa91f9f";
    hash = "sha256-se0krTglo1fShJXj38bPLhw65tZC5P54Ywt7oeZrLes=";
  })
  (mw-ext {
    name = "TemplateData";
    commit = "d37b02f6ed194138ac7193a0782bbf6efb9164f8";
    hash = "sha256-NpzVBzX7qfXkIE+jh33ndooS9GE8ZF3/Jynm22in7IQ=";
  })
  (mw-ext {
    name = "TemplateStyles";
    commit = "f85614c26a0057a9f418342f89214a04c9de9988";
    hash = "sha256-XZOtM3iadjE5vavsjkx7kfJNhLZlnnFt1CN+mv6XVHQ=";
  })
  (mw-ext {
    name = "UserMerge";
    commit = "2f2432c909a36691ca0002daf6fb304d6c182beb";
    hash = "sha256-ZP8Tp6u+uJxx3I39YGMmkP0sTnjAQUSaxImAJaRv+Ek=";
  })
  (mw-ext {
    name = "VisualEditor";
    commit = "1508d49d0dd71fdc1d18badd23671441b3bc327b";
    hash = "sha256-VNiCVNrCAImAr1tS9T28KPPzzNsKPz5ELFRIBtng+So=";
  })
  (mw-ext {
    name = "WikiEditor";
    commit = "aba5e7c6701877a6b43583709751658fec606d47";
    hash = "sha256-XmbQy0NXuY3oVGkkgC233kkzfBfx32HDylloGYXU/Nc=";
  })
]
