{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "jackson";
  version = "1.9.6";

  src = fetchFromGitHub {
    owner = "boxyhq";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-iZKl2dBBEQLemHMSa6rXYAuCo02WhG/BcYKTmCm46hI=";
  };

  prePhase = ''
    export HOME=$TMPDIR
  '';

  npmDepsHash = "sha256-pYGdbmfewdvVuNfuWLlj5TmxQGdQfqPZs6TXzttoHYo=";

  # The prepack script runs the build script, which we'd rather do in the build phase.
  npmFlags = [ "--loglevel silent" ];


  #NODE_OPTIONS = "--openssl-legacy-provider";

  meta = with lib; {
    description = "Enterprise SSO made simple";
    homepage = "https://github.com/boxyhq/jackson";
    license = licenses.asl20;
    maintainers = with maintainers; [ felixalbrigtsen ];
  };
}
