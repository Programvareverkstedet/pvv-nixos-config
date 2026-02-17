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
    hash = "sha256-4d0TwJubfJrThctvE50HpPg0gqdJy595hewEcjfXlrs=";
    domain = "git.pvv.ntnu.no";
  };
  
   installPhase = ''
    cp -r * $out/
   '';

}
