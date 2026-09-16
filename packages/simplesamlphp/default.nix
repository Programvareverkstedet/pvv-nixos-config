{ lib
, php
, writeShellApplication
, jq
, coreutils
, git
, nix
, gnused
, gnugrep
, fetchFromGitHub

, extra_files ? { }
, enableOidc ? true
}:
let
  pname = "simplesamlphp";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "simplesamlphp";
    repo = "simplesamlphp";
    tag = "v${version}";
    hash = "sha256-Md07vWhB/5MDUH+SPQEs8PYiUrkEgAyqQl+LO+ap0Sw=";
  };

  extraComposerRequires = lib.optionalAttrs enableOidc {
    "simplesamlphp/simplesamlphp-module-oidc" = "^6.4";
  };

  vendorHash = {
    default = "sha256-GrEoGJXEyI1Ib+06GIuo5eRwxQ0UMKeX5RswShu2CHM=";
    oidc = "sha256-PR+Q/xJa1V511d9Zpnp6m3e9AXQK5gIgVgTZsOhqamw=";
  }.${if enableOidc then "oidc" else "default"};

  commonComposerArgs = {
    inherit pname version src vendorHash;
    composerNoDev = true;
    composerNoPlugins = true;
    composerNoScripts = true;
    composerStrictValidation = false;
  };

  composerLockOverride = lib.optionalAttrs enableOidc { composerLock = ./composer-oidc.lock; };

  composerPostPatch = lib.optionalString (extraComposerRequires != { }) ''
    jq --argjson extra ${lib.escapeShellArg (builtins.toJSON extraComposerRequires)} \
      '.require += $extra' composer.json > composer.json.tmp
    mv composer.json.tmp composer.json
    rm -f composer.lock
  '';

  moduleSymlinks = lib.pipe extraComposerRequires [
    lib.attrNames
    (lib.filter (lib.hasPrefix "simplesamlphp/simplesamlphp-module-"))
    (map (packageName: let
      moduleName = lib.removePrefix "simplesamlphp/simplesamlphp-module-" packageName;
    in
    ''
      ln -sr \
        "$out"/share/php/simplesamlphp/vendor/'${packageName}' \
        "$out"/share/php/simplesamlphp/modules/'${moduleName}'
    ''))
    lib.concatLines
  ];
in
php.buildComposerProject ({
  inherit (commonComposerArgs) pname version src vendorHash;
  inherit (commonComposerArgs) composerNoDev composerNoPlugins composerNoScripts composerStrictValidation;

  composerRepository = php.mkComposerRepository (
    commonComposerArgs // { postPatch = composerPostPatch; } // composerLockOverride
  );

  # TODO: metadata could be fetched automagically with these:
  #   - https://simplesamlphp.org/docs/contrib_modules/metarefresh/simplesamlphp-automated_metadata.html
  #   - https://idp.pvv.ntnu.no/simplesaml/saml2/idp/metadata.php
  postPatch = composerPostPatch + lib.pipe extra_files [
    (lib.mapAttrsToList (target_path: source_path: ''
      mkdir -p $(dirname "${target_path}")
      cp -r "${source_path}" "${target_path}"
    ''))
    lib.concatLines
  ];

  postInstall = ''
    ln -sr \
      "$out"/share/php/simplesamlphp/vendor/simplesamlphp/simplesamlphp-assets-base \
      "$out"/share/php/simplesamlphp/public/assets/base
  '' + moduleSymlinks;

  passthru = {
    inherit php;

    updateScript = writeShellApplication {
      name = "update-${pname}-composer-lock";
      runtimeInputs = [
        coreutils
        git
        gnugrep
        gnused
        jq
        nix
        php
        php.packages.composer
      ];
      text = ''
        repoRoot="$(git rev-parse --show-toplevel)"
        packageDir="$repoRoot/packages/simplesamlphp"
        lockfile="$packageDir/composer-oidc.lock"
        defaultNix="$packageDir/default.nix"

        if [ ! -e "$lockfile" ]; then
          echo "Expected $lockfile to exist, but it is missing. Aborting."
          exit 1
        fi

        workdir="$(mktemp -d)"
        trap 'rm -rf "$workdir"' EXIT

        cp -r --no-preserve=mode,ownership ${src}/. "$workdir"/
        cd "$workdir"

        ${composerPostPatch}

        export COMPOSER_MIRROR_PATH_REPOS=1
        export COMPOSER_CACHE_DIR="$workdir/.composer-cache"
        export COMPOSER_HTACCESS_PROTECT=0
        export COMPOSER_ROOT_VERSION="${version}"

        composer ${lib.cli.toCommandLineShellGNU { } {
          no-interaction = true;
          no-progress = true;
          no-dev = commonComposerArgs.composerNoDev;
          no-plugins = commonComposerArgs.composerNoPlugins;
          no-scripts = commonComposerArgs.composerNoScripts;
        }} update

        cp composer.lock "$lockfile"
        echo "Wrote $lockfile"

        discoverVendorHash() {
          local output
          output=$(
            nix build \
              --impure \
              --no-link \
              --argstr packageDir "$packageDir" \
              --arg enableOidc "$1" \
              --expr '
                { packageDir, enableOidc }:
                let pkgs = import <nixpkgs> { };
                in (pkgs.callPackage (/. + packageDir) { inherit enableOidc; }).composerRepository.overrideAttrs (_: {
                  outputHash = pkgs.lib.fakeHash;
                })
              ' \
              2>&1
          ) ||:
          echo "$output" | grep -oE 'got: *sha256-[A-Za-z0-9+/=]+' | sed -E 's/^got: *//'
        }

        echo "Regenerating default vendorHash..."
        defaultHash=$(discoverVendorHash false)
        echo "Regenerating oidc vendorHash..."
        oidcHash=$(discoverVendorHash true)

        if [ -z "$defaultHash" ] || [ -z "$oidcHash" ]; then
          echo "Failed to regenerate vendorHash values, aborting."
          exit 1
        fi

        sed -i \
          -e "s|default = \"sha256-[A-Za-z0-9+/=]*\";|default = \"$defaultHash\";|" \
          -e "s|oidc = \"sha256-[A-Za-z0-9+/=]*\";|oidc = \"$oidcHash\";|" \
          "$defaultNix"

        echo "Wrote new vendorHash values to $defaultNix:"
        echo "  default: $defaultHash"
        echo "  oidc: $oidcHash"
      '';
    };
  };
} // composerLockOverride)
