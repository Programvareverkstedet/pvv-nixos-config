{
  lib,
  fetchgit,
  makeWrapper,
  nodejs,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "delete-your-element";
  version = "3.1-unstable-2025-06-22";
  src = fetchgit {
    url = "https://git.pvv.ntnu.no/Drift/delete-your-element.git";
    rev = "cdc3b95858419568c7058d4f0056b14dbbf1152b";
    sha256 = "sha256-v6PFyduwve6uwqBB5mzXMP09GwaxGjv1xIzgs/Eeolc=";
  };
  npmDepsHash = "sha256-HNHEGez8X7CsoGYXqzB49o1pcCImfmGYIw9QKF2SbHo=";
  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

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
