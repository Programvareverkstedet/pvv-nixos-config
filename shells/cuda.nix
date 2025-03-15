# nix develop .#cuda
# Copied from https://nixos.wiki/wiki/CUDA
{ pkgs }:

pkgs.mkShell {
  name = "cuda-env-shell";
  buildInputs = with pkgs; [
    autoconf
    binutils
    curl
    freeglut
    git
    gitRepo
    gnumake
    gnupg
    gperf
    libGL
    libGLU
    m4
    ncurses5
    procps
    stdenv.cc
    unzip
    util-linux
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXmu
    xorg.libXrandr
    xorg.libXv
    zlib

    cudatoolkit
    linuxPackages.nvidia_x11

    # Other applications, like
    hashcat
  ];

  env = {
    CUDA_PATH = pkgs.cudatoolkit;
    EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
    EXTRA_CCFLAGS = "-I/usr/include";
  };
}
