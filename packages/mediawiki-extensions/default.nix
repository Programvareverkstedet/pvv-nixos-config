{ pkgs, lib }:
lib.makeScope pkgs.newScope (self: {
  DeleteBatch = self.callPackage ./delete-batch { };
  PluggableAuth = self.callPackage ./pluggable-auth { };
  SimpleSAMLphp = self.callPackage ./simple-saml-php { };
  UserMerge = self.callPackage ./user-merge { };
  VisualEditor = self.callPackage ./visual-editor { };
})
