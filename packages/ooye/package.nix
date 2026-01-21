{
  lib,
  fetchFromGitea,
  makeWrapper,
  nodejs_24,
  buildNpmPackage,
}:
let
  nodejs = nodejs_24;
in
buildNpmPackage {
  pname = "delete-your-element";
  version = "3.3-unstable-2026-01-21";
  src = fetchFromGitea {
    domain = "git.pvv.ntnu.no";
    owner = "Drift";
    repo = "delete-your-element";
    rev = "04d7872acb933254c0a4703064b2e08de31cfeb4";
    hash = "sha256-CkKt+8VYjIhNM76c3mTf7X6d4ob8tB2w8T6xYS7+LuY=";
  };

  inherit nodejs;

  patches = [ ./fix-lockfile.patch ];

  npmDepsHash = "sha256-tiGXr86x9QNAwhZcxSOox6sP9allyz9QSH3XOZOb3z8=";
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
