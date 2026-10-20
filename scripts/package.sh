#!/bin/bash
# Build from committed files, not the user's untracked files or local secrets.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
VERSION=$(sed -n "s/.*echo 'orphan-cleanup \([^']*\)'.*/\1/p" lib/cli.sh)
[ -n "$VERSION" ] || exit 1
mkdir -p dist
NAME="orphan-cleanup-$VERSION"
git archive --format=tar --prefix="$NAME/" HEAD | gzip -n > "dist/$NAME.tar.gz"
(cd dist && shasum -a 256 "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
printf '%s\n' "$ROOT/dist/$NAME.tar.gz"
