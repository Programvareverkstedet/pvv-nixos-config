{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShellNoCC {
  packages = with pkgs; [
    sops
    gnupg
    openstackclient
  ];

  shellHook = ''
    export OS_AUTH_URL=https://api.stack.it.ntnu.no:5000
    export OS_PROJECT_ID=b78432a088954cdc850976db13cfd61c
    export OS_PROJECT_NAME="STUDORG_Programvareverkstedet"
    export OS_USER_DOMAIN_NAME="NTNU"
    export OS_PROJECT_DOMAIN_ID="d3f99bcdaf974685ad0c74c2e5d259db"
    export OS_REGION_NAME="NTNU-IT"
    export OS_INTERFACE=public
    export OS_IDENTITY_API_VERSION=3
  '';
}
