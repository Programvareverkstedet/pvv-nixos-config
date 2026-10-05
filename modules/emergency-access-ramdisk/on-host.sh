# Run a command sourced from the ramdisk in the host's mount namespace,
# so that it can see the real filesystem instead of just the one mounted at /host.

if [ $# -eq 0 ]; then
  # Avoid reading any rc files from the host's (possibly dead) filesystem
  if [ -x /bin/bash ]; then
    set -- bash --norc --noprofile
  else
    set -- sh
  fi
fi

exec nsenter --target 1 --mount -- "$MOUNTPOINT/host-bin/env" -i \
  PATH="$MOUNTPOINT/host-bin" \
  HOME="$MOUNTPOINT/root" \
  TERM="${TERM:-dumb}" \
  TERMINFO="$MOUNTPOINT$TERMINFO_DIR" \
  INPUTRC=/dev/null \
  PS1='[on-host@\h:\w]\$ ' \
  "$@"
