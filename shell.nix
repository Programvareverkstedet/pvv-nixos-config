{ pkgs ? import <nixpkgs> {} }:

let
  nixos-rebuild-nom = pkgs.writeScriptBin "nixos-rebuild" ''
    if [[ -t 1 && -z "''${NIX_NO_NOM-}" ]]; then
      exec ${pkgs.lib.getExe pkgs.nixos-rebuild} -L "$@" |& ${pkgs.lib.getExe pkgs.nix-output-monitor}
    else
      exec ${pkgs.lib.getExe pkgs.nixos-rebuild} -L "$@"
    fi
  '';
in

pkgs.mkShellNoCC {
  packages = with pkgs; [
    nixos-rebuild-nom
    just
    jq
    gum
    sops
    gnupg
    statix
    openstackclient
    editorconfig-checker
  ];

  env = {
    OS_AUTH_URL = "https://api.stack.it.ntnu.no:5000";
    OS_PROJECT_ID = "b78432a088954cdc850976db13cfd61c";
    OS_PROJECT_NAME = "STUDORG_Programvareverkstedet";
    OS_USER_DOMAIN_NAME = "NTNU";
    OS_PROJECT_DOMAIN_ID = "d3f99bcdaf974685ad0c74c2e5d259db";
    OS_REGION_NAME = "NTNU-IT";
    OS_INTERFACE = "public";
    OS_IDENTITY_API_VERSION = "3";
  };
}
