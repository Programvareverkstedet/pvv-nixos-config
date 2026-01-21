#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash git gnugrep gnused nodejs_24

GIT_TOPLEVEL=$(git rev-parse --show-toplevel)
PACKAGE_NIX="$GIT_TOPLEVEL/packages/ooye/package.nix"
REV="$(grep -oP '(?<=rev = ")[a-z0-9]+(?=")' "$PACKAGE_NIX")"

TMPDIR="$(mktemp -d)"

cleaning() {
  rm -rf "$TMPDIR"
}

trap 'cleaning' SIGINT

git clone --depth 1 --revision="$REV" https://git.pvv.ntnu.no/Drift/delete-your-element.git "$TMPDIR/ooye"
pushd "$TMPDIR/ooye" || exit
  sed -i 's/\s*"glob@<11.1": "^12"//' package.json
  git diff --quiet --exit-code package.json && {
    echo "Sed did't do it's job, please fix" >&2
    cleaning
    exit 1
  }

  rm -rf package-lock.json
  npm install --package-lock-only

  export GIT_AUTHOR_NAME='Lockinator 9000'
  export GIT_AUTHOR_EMAIL='locksmith@lockal.local'
  export GIT_AUTHOR_DATE='Sun, 01 Jan 1984 00:00:00 +0000'
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"

  git commit -am "package-lock.json: bomp" --no-gpg-sign
  git format-patch HEAD~
  mv 0001-package-lock.json-bomp.patch "$GIT_TOPLEVEL/packages/ooye/fix-lockfile.patch"
  git reset --hard HEAD~
popd || exit
cleaning
