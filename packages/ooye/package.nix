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
    rev = "dd803378e66eec6e6984dd8d8f9a305ee6c41c21";
    hash = "sha256-GubaUgu1sOCn/7JncMgkLJv/RC1rEWmUQS5JR6DDo+Q=";
  };

  inherit nodejs;

  npmDepsHash = "sha256-2qjSF2m5cmKMS8z09bRFraj1mUowaHrEHjy/RgFYDlA=";
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
