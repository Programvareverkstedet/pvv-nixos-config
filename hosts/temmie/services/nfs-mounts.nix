{ pkgs, lib, ... }:
{
  fileSystems = let
    # See microbel:/etc/exports
    shorthandAreas = lib.listToAttrs (map
      (l: lib.nameValuePair "/run/pvv-home-mounts/${l}" "homepvv${l}.pvv.ntnu.no:/export/home/pvv/${l}")
      [ "a" "b" "c" "d"  "h" "i" "j" "k" "l" "m" "z" ]);
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
