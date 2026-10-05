{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ssacli";
  # NOTE: 6.x only supports Gen10 and newer controllers.
  version = "5.30-6.0";

  src = fetchurl {
    url = "https://downloads.linux.hpe.com/SDR/repo/mcp/debian/pool/non-free/ssacli-${finalAttrs.version}_amd64.deb";
    hash = "sha256-e+I/AEvDxQKu/Ts+ov4/6PGhLgxCVp1mRecrcR8isOk=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -Dm555 -t $out/libexec/ssacli opt/smartstorageadmin/ssacli/bin/{ssacli,ssascripting,rmstr}
    install -Dm444 -t $out/share/doc/ssacli opt/smartstorageadmin/ssacli/bin/{ssacli-${finalAttrs.version}.x86_64.txt,ssacli.license}
    install -Dm444 -t $out/share/man/man8 usr/man/man8/ssacli.8.gz

    for bin in ssacli ssascripting; do
      makeWrapper $out/libexec/ssacli/$bin $out/bin/$bin \
        --set SSACLI_BIN_INSTALLATION_DIR $out/libexec/ssacli/
    done

    runHook postInstall
  '';

  meta = {
    description = "HPE Smart Storage Administrator CLI for Smart Array controllers";
    homepage = "https://support.hpe.com/connect/s/softwaredetails?language=en_US&softwareId=MTX_04bffb688a73438598fef81ddd";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    # license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ssacli";
  };
})
