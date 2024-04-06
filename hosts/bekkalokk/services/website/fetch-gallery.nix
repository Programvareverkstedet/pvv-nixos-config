{ pkgs, lib, config, ... }:
let
  galleryDir = config.services.pvv-nettsiden.settings.GALLERY.DIR;
  transferDir = "${config.services.pvv-nettsiden.settings.GALLERY.DIR}-transfer";
in {
  users.users.${config.services.pvv-nettsiden.user} = {
    useDefaultShell = true;

    # This is pushed from microbel:/var/www/www-gallery/build-gallery.sh
    openssh.authorizedKeys.keys = [
    ''command="${pkgs.rrsync}/bin/rrsync -wo ${transferDir}",restrict,no-agent-forwarding,no-port-forwarding,no-pty,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjHhC2dikhWs/gG+m7qP1eSohWzTehn4ToNzDSOImyR gallery-publish''
    ];
  };

  systemd.paths.pvv-nettsiden-gallery-update = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "${transferDir}/gallery.tar.gz";
      Unit = "pvv-nettsiden-gallery-update.service";
      MakeDirectory = true;
    };
  };

  systemd.services.pvv-nettsiden-gallery-update = {
    path = with pkgs; [ imagemagick gnutar gzip ];

    script = ''
      tar ${lib.cli.toGNUCommandLineShell {} {
        extract = true;
        file = "${transferDir}/gallery.tar.gz";
        directory = ".";
      }}

      # Delete files and directories that exists in the gallery that don't exist in the tarball
      filesToRemove=$(uniq -u <(sort <(find . -not -path "./.thumbnails*") <(tar -tf ${transferDir}/gallery.tar.gz | sed 's|/$||')))
      while IFS= read fname; do
        rm -f $fname ||:
        rm -f .thumbnails/$fname.png ||:
      done <<< "$filesToRemove"

      find . -type d -empty -delete

      mkdir -p .thumbnails
      images=$(find . -type f -not -path "./.thumbnails*")

      while IFS= read fname; do
        [ -f ".thumbnails/$fname.png" ] && continue ||:

        echo "Creating thumbnail for $fname"
        mkdir -p $(dirname ".thumbnails/$fname")
        convert -define jpeg:size=200x200 "$fname" -thumbnail 500 -auto-orient ".thumbnails/$fname.png" ||:
      done <<< "$images"
    '';

    serviceConfig = {
      WorkingDirectory = galleryDir;
      User = config.services.pvv-nettsiden.user;
      Group = config.services.pvv-nettsiden.group;
    };
  };
}
