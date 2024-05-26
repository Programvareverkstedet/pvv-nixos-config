{ pkgs, lib }:
{
  DeleteBatch = pkgs.callPackage ./delete-batch { };
  PluggableAuth = pkgs.callPackage ./pluggable-auth { };
  SimpleSAMLphp = pkgs.callPackage ./simple-saml-php { };
  UserMerge = pkgs.callPackage ./user-merge { };
  VisualEditor = pkgs.callPackage ./visual-editor { };
}
