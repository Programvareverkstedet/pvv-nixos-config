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
  version = "3.6.0";
  src = fetchFromGitea {
    domain = "git.pvv.ntnu.no";
    owner = "Drift";
    repo = "delete-your-element";
    rev = "44fb6a02d3139e8ab10e9660ad931e5e70d1205f";
    hash = "sha256-wDQhPbxwdkAm0kPhaDNjbk8rVFxnGinffVdASdFrYnU=";
  };

  inherit nodejs;

  npmDepsHash = "sha256-h1mmE0/+Y7SBwnI0vaYvV+KqRDJGzwJvDUOkigzHcOY=";
  dontNpmBuild = true;

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
