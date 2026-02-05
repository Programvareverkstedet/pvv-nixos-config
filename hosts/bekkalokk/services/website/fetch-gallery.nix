{ pkgs, lib, config, values, ... }:
let
  galleryDir = config.services.pvv-nettsiden.settings.GALLERY.DIR;
  transferDir = "${config.services.pvv-nettsiden.settings.GALLERY.DIR}-transfer";
in {
  users.users.${config.services.pvv-nettsiden.user} = {
    # NOTE: the user unfortunately needs a registered shell for rrsync to function...
    #       is there anything we can do to remove this?
    useDefaultShell = true;
  };

  # This is pushed from microbel:/var/www/www-gallery/build-gallery.sh
  services.rsync-pull-targets = {
    enable = true;
    locations.${transferDir} = {
      user = config.services.pvv-nettsiden.user;
      rrsyncArgs.wo = true;
      authorizedKeysAttrs = [
        "restrict"
        "from=\"microbel.pvv.ntnu.no,${values.hosts.microbel.ipv6},${values.hosts.microbel.ipv4}\""
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjHhC2dikhWs/gG+m7qP1eSohWzTehn4ToNzDSOImyR gallery-publish";
    };
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
        rm -f "$fname" ||:
        rm -f ".thumbnails/$fname.png" ||:
      done <<< "$filesToRemove"

      find . -type d -empty -delete

      mkdir -p .thumbnails
      images=$(find . -type f -not -path "./.thumbnails*")

      while IFS= read fname; do
        # Skip this file if an up-to-date thumbnail already exists
        if [ -f ".thumbnails/$fname.png" ] && \
          [ "$(date -R -r "$fname")" == "$(date -R -r ".thumbnails/$fname.png")" ]
        then
          continue
        fi

        echo "Creating thumbnail for $fname"
        mkdir -p $(dirname ".thumbnails/$fname")
        magick -define jpeg:size=200x200 "$fname" -thumbnail 300 -auto-orient ".thumbnails/$fname.png" ||:
        touch -m -d "$(date -R -r "$fname")" ".thumbnails/$fname.png"
      done <<< "$images"
    '';

    serviceConfig = {
      WorkingDirectory = galleryDir;
      User = config.services.pvv-nettsiden.user;
      Group = config.services.pvv-nettsiden.group;

      AmbientCapabilities = [ "" ];
      CapabilityBoundingSet = [ "" ];
      DeviceAllow = [ "" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true; # disable for third party rotate scripts
      PrivateDevices = true;
      PrivateNetwork = true; # disable for mail delivery
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true; # disable for userdir logs
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "full";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true; # disable for creating setgid directories
      SocketBindDeny = [ "any" ];
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
      ];
    };
  };
}
