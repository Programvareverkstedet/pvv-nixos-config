{ lib
, php
, stdenv
, writeText
, fetchFromGitea
, extra_files ? { }

}:


stdenv.mkDerivation {
  pname = "ssp-theme";
  version = "v1.2026";
  
  src = fetchFromGitea {
    owner = "drift";
    repo = "ssp-theme";
    rev = "master";
    sha256 = "source-hash";
    domain = "git.pvv.ntnu.no";
  };

}
