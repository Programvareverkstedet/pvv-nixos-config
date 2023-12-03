{ pkgs, lib, ... }:
{
  fileSystems = let
    # See microbel:/etc/exports
    homeMounts = (lib.listToAttrs (map
      (l: lib.nameValuePair "/home/pvv/${l}" "homepvv${l}.pvv.ntnu.no:/export/home/pvv/${l}")
      [ "a" "b" "c" "d"  "h" "i" "j" "k" "l" "m" "z" ]));
  in { }
  //
  (lib.mapAttrs (_: device: {
    inherit device;
    fsType = "nfs";
    options = [
      "nfsvers=3"
      "proto=tcp"
      "nofail"
      "_netdev"
    ];
  }) homeMounts);
}
