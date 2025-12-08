{
  lib,
  fetchFromGitea,
  makeWrapper,
  nodejs,
  buildNpmPackage,
  fetchpatch,
}:
buildNpmPackage {
  pname = "delete-your-element";
  version = "3.3-unstable-2025-12-09";
  src = fetchFromGitea {
    domain = "git.pvv.ntnu.no";
    owner = "Drift";
    repo = "delete-your-element";
    rev = "1c0c545a024ef7215a1a3483c10acce853f79765";
    hash = "sha256-ow/PdlHfU7PCwsjJUEzoETzONs1KoKTRMRQ9ADN0tGk=";
  };

  patches = [
    (fetchpatch {
      name = "ooye-fix-package-lock-0001.patch";
      url = "https://cgit.rory.gay/nix/OOYE-module.git/plain/pl.patch?h=ee126389d997ba14be3fe3ef360ba37b3617a9b2";
      hash = "sha256-dP6WEHb0KksDraYML+jcR5DftH9BiXvwevUg38ALOrc=";
    })
  ];

  npmDepsHash = "sha256-OXOyO6LxK/WYYVysSxkol0ilMUZB+osLYUE5DpJlbps=";
  # npmDepsHash = "sha256-Y+vgp7+7pIDm64AYSs8ltoAiON0EPpJInbmgn3/LkVA=";
  dontNpmBuild = true;
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -a . $out/share/ooye
    makeWrapper ${nodejs}/bin/node $out/bin/matrix-ooye --add-flags $out/share/ooye/start.js
    makeWrapper ${nodejs}/bin/node $out/bin/matrix-ooye-addbot --add-flags $out/share/ooye/addbot.js

    runHook postInstall
  '';

  meta = with lib; {
    description = "Matrix-Discord bridge with modern features.";
    homepage = "https://gitdab.com/cadence/out-of-your-element";
    longDescription = ''
      Modern Matrix-to-Discord appservice bridge, created by @cadence:cadence.moe.
    '';
    license = licenses.gpl3;
    # maintainers = with maintainers; [ RorySys ];
    mainProgram = "matrix-ooye";
  };
}
