{ lib, ... }:
with lib;
let
  # get all files in folder
  getDir = dir: builtins.readDir dir;

  # find all files ending in ".nix" which are not this file, or directories, which may or may not contain a default.nix
  files = dir: filterAttrs
    (file: type: (type == "regular" && hasSuffix ".nix" file && file != "default.nix") || type == "directory")
    (getDir dir);
  # Turn the attrset into a list of the filenames
  flatten = dir: mapAttrsToList (file: type: file) (files dir);
  # Turn the filenames into absolute paths
  makeAbsolute = dir: map (file: ./. + "/${file}") (flatten dir);
in
{

  imports = makeAbsolute ./.;

}
