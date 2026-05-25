{
  lib
, rustPlatform
, stdenv
}:
let
  cargoToml = fromTOML (builtins.readFile ./Cargo.toml);
  cargoLock = ./Cargo.lock;
  mainProgram = (lib.head cargoToml.bin).name;
  pname = cargoToml.package.name;
in
rustPlatform.buildRustPackage {
  inherit pname;
  inherit (cargoToml.package) version;
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  cargoLock.lockFile = cargoLock;

  doCheck = true;

  meta = with lib; {
    license = licenses.mit;
    platforms = platforms.linux;
    inherit mainProgram;
  };
}
