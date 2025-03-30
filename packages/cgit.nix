{ cgit, fetchurl, ... }:
let
  pname = cgit.pname;
  commit = "09d24d7cd0b7e85633f2f43808b12871bb209d69";
in
cgit.overrideAttrs (_: {
  version = "1.2.3-unstable-2024.07.16";

  src = fetchurl {
    url = "https://git.zx2c4.com/cgit/snapshot/${pname}-${commit}.tar.xz";
    hash = "sha256-gfgjAXnWRqVCP+4cmYOVdB/3OFOLJl2WBOc3bFVDsjw=";
  };

  # cgit is tightly coupled with git and needs a git source tree to build.
  # IMPORTANT: Remember to check which git version cgit needs on every version
  # bump (look for "GIT_VER" in the top-level Makefile).
  gitSrc = fetchurl {
    url = "mirror://kernel/software/scm/git/git-2.46.0.tar.xz";
    hash = "sha256-fxI0YqKLfKPr4mB0hfcWhVTCsQ38FVx+xGMAZmrCf5U=";
  };
})
