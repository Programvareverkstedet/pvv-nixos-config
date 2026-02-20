{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
}:

buildPythonPackage rec {
  pname = "matrix-synapse-smtp-auth";
  version = "0.1.0";

  src = ./.;

  pyproject = true;
  build-system = [ setuptools ];

  doCheck = false;

  meta = with lib; {
    description = "An SMTP auth provider for Synapse";
    homepage = "pvv.ntnu.no";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ dandellion ];
  };
}
