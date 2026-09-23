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
  version = "3.7.0";
  src = fetchFromGitea {
    domain = "git.pvv.ntnu.no";
    owner = "Drift";
    repo = "delete-your-element";
    rev = "e6c6013fa35c1120f719249c2dc61e58e92d6ef0";
    hash = "sha256-rnWOBOh4AaInn6mgTPVCp79FYVqCTmpzsYiGKcsTjwg=";
  };

  inherit nodejs;

  npmDepsHash = "sha256-aNwHFG1BGEiI6hv7jeSUUbe4ZjcWXD8MlvklbpxCAKQ=";
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
