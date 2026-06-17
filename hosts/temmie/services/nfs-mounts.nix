{ lib, pkgs, values, ... }:
let
  # See microbel:/etc/exports
  letters = [ "a" "b" "c" "d" "h" "i" "j" "k" "l" "m" "z" ];
in
{
  systemd.targets."pvv-homedirs" = {
    description = "PVV Homedir Partitions";
    requires = map (l: "pvv-homedir-create-uidmapped-bindmounts@${l}.service") letters;
  };

  systemd.tmpfiles.settings."10-pvv-homedirs" = {
    "/run/pvvhome".d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
    "/run/pvvhome/by-uid".d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
  };

  systemd.mounts = map (l: {
    description = "PVV Homedir Partition ${l}";

    before = [ "remote-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    requiredBy = [ "pvv-homedirs.target" ];

    type = "nfs";
    what = "homepvv${l}.pvv.ntnu.no:/export/home/pvv/${l}";
    where = "/run/pvvhome/${l}";

    options = lib.concatStringsSep "," [
      "nfsvers=3"

      # NOTE: this is a bit unfortunate. The address above seems to resolve to IPv6 sometimes,
      #       and it doesn't seem possible to specify proto=tcp,tcp6, meaning we have to tell
      #       NFS which exact address to use here, despite it being specified in the `what` attr :\
      "proto=tcp"
      "addr=${values.hosts.microbel.ipv4}"
      "mountproto=tcp"
      "mounthost=${values.hosts.microbel.ipv4}"
      "port=2049"

      # NOTE: this is yet more unfortunate. When enabling locking, it will sometimes complain about connection failed.
      #       dmesg(1) reveals that it has something to do with registering the lockdv1 RPC service (errno: 111), not
      #       quite sure how to fix it. Living life on dangerous mode for now.
      "nolock"

      # Don't wait on every read/write
      "async"

      # Always keep mounted
      "noauto"

      # We don't want to update access time constantly
      "noatime"

      # No SUID/SGID, no special devices
      "nosuid"
      "nodev"

      # TODO: are there cgi scripts that modify stuff in peoples homedirs?
      # "ro"
      "rw"
    ];
  }) letters;

  systemd.services."pvv-homedir-create-uidmapped-bindmounts@" = {
    bindsTo = [ "run-pvvhome-%i.mount" ];
    after = [ "run-pvvhome-%i.mount" ];

    serviceConfig = {
      Type = "oneshot";
    };

    path = with pkgs; [
      coreutils
      systemdMinimal
    ];

    scriptArgs = "%i";
    script = ''
      for dir in "/run/pvvhome/$1"/*/; do
          [[ -d "$dir" ]] || continue

          uid="$(stat -c '%u' "$dir")"

          mountpoint="/run/pvvhome/by-uid/$uid"
          mkdir -p "$mountpoint"

          unit_name=$(systemd-escape --path --suffix=mount "$mountpoint")

          if systemctl --quiet is-active "$unit_name" ||
             systemctl --quiet is-failed "$unit_name"; then
              echo "Skipping existing mount unit: $unit_name"
              continue
          fi

          systemd-mount \
              --collect \
              --fsck=no \
              --type=none \
              --options=bind \
              --property=BindsTo=$(systemd-escape --path --suffix=mount "/run/pvvhome/$1") \
              --property=After=$(systemd-escape --path --suffix=mount "/run/pvvhome/$1") \
              "$dir" \
              "$mountpoint" \
         || echo "Failed mounting for uid $uid"
      done
    '';
  };
}
