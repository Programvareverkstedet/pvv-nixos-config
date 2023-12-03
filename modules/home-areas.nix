{ pkgs, lib, ... }:
{
  fileSystems = let
    shorthandAreas = {
      # See toriel:/etc/exports
      "/home/pvv/t/pederbs" = "homepvvt.pvv.ntnu.no:/export/home/pvv/t/pederbs";
      "/home/pvv/t/yorinad" = "homepvvt.pvv.ntnu.no:/export/home/pvv/t/yorinad";
    }
    //
    # See microbel:/etc/exports
    (lib.listToAttrs (map
      (l: lib.nameValuePair "/home/pvv/${l}" "homepvv${l}.pvv.ntnu.no:/export/home/pvv/${l}")
      [ "a" "b" "c" "d"  "h" "i" "j" "k" "l" "m" "z" ]));
  in { }
  //
  (lib.mapAttrs (_: device: {
    inherit device;
    fsType = "nfs";
    options = [
      "nfsvers=3"
      "noauto"
      "proto=tcp"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
    ];
  }) shorthandAreas);
}
