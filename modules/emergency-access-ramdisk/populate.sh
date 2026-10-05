#!/usr/bin/env bash
# Usage: populate.sh MOUNTPOINT IMAGE [HOST_KEY...]
#
# Copies IMAGE into the ramfs mounted at MOUNTPOINT and mounts it,
# or atomically swaps it if another image is already mounted.
#
# Requires Linux >= 6.5 for `mount --beneath`.

set -euo pipefail
shopt -s nullglob extglob

declare -r MOUNTPOINT=$1
declare -r IMAGE=$2
shift 2
declare -ar HOST_KEYS=("$@")

declare -r FILENAME=${IMAGE##*/}
declare -r NAME=${FILENAME%.erofs}

# Writable parts of the ramfs, created as directories
declare -ar RAMFS_DIRECTORIES=(
  dev
  host
  host-keys
  image
  images
  proc
  root
  run
  sys
  tmp
)

# Read-only symlinks to where the prebuilt read-only image is mounted.
declare -ar EROFS_SYMLINKS=(
  bin
  etc
  host-bin
  nix
  sbin
  usr
  var
)

mkdir -p "${RAMFS_DIRECTORIES[@]/#/$MOUNTPOINT/}"
chmod 1777 "$MOUNTPOINT/tmp"

for LINK in "${EROFS_SYMLINKS[@]}"; do
  [ -L "$MOUNTPOINT/$LINK" ] || ln -s "image/$LINK" "$MOUNTPOINT/$LINK"
done

# Modern EROFS mounts don't need loop devices since Linux 6.12, but it only works for some
# underlying filesystems, and it's nice to fall back to something that works anyway.
mount_image() {
  local -r MOUNT=$1
  shift
  "$MOUNT" -t erofs -o ro,X-mount.noloop "$@" || "$MOUNT" -t erofs -o ro,loop "$@"
}

if ! mountpoint -q "$MOUNTPOINT/image"; then
  cp "$IMAGE" "$MOUNTPOINT/images/$NAME.erofs"
  mount_image mount "$MOUNTPOINT/images/$NAME.erofs" "$MOUNTPOINT/image"
elif [ "$(cat "$MOUNTPOINT/images/current" 2>/dev/null)" != "$NAME" ]; then
  # Atomically swap in the new image, using the mount binary from the current one.
  # Sessions still using the old image keep it alive until they exit.
  cp "$IMAGE" "$MOUNTPOINT/images/$NAME.erofs"
  mount_image "$MOUNTPOINT/host-bin/mount" --beneath "$MOUNTPOINT/images/$NAME.erofs" "$MOUNTPOINT/image"
  umount --lazy "$MOUNTPOINT/image"
fi
echo "$NAME" > "$MOUNTPOINT/images/current"

# Remove every image except the current one
rm -f "$MOUNTPOINT"/images/!("$NAME").erofs

# Hopefully at least one of these will work (else we have a problem...)
declare -i INSTALLED_HOST_KEYS=0
for HOST_KEY in "${HOST_KEYS[@]}"; do
  if install -Dm600 "$HOST_KEY" "$MOUNTPOINT/host-keys/${HOST_KEY##*/}"; then
    INSTALLED_HOST_KEYS+=1
  else
    echo "warning: failed to install host key $HOST_KEY" >&2
  fi
done

if (( INSTALLED_HOST_KEYS == 0 )); then
  echo "error: failed to install any host keys, sshd would not be able to start" >&2
  exit 1
fi
