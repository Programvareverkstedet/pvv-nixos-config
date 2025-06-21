{
  lib,
  fetchgit,
  makeWrapper,
  nodejs,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "out-of-your-element";
  version = "3.1-unstable-2025-06-21";
  src = fetchgit {
    url = "https://gitdab.com/cadence/out-of-your-element.git";
    rev = "efaa59ca9293a56b57d997d3dc7c5bd7564d07d4";
    sha256 = "sha256-KxpmqxELXWCAPefa2bHyFTtPkvZkaeZqEL9fi6w6rLw=";
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
