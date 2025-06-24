{
  lib,
  fetchgit,
  makeWrapper,
  nodejs,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "delete-your-element";
  version = "3.1-unstable-2025-06-23";
  src = fetchgit {
    url = "https://git.pvv.ntnu.no/Drift/delete-your-element.git";
    rev = "67658bf68026918163a2e5c2a30007364c9b2d2d";
    sha256 = "sha256-jSQ588kwvAYCe6ogmO+jDB6Hi3ACJ/3+rC8M94OVMNw=";
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
