#!/bin/bash
# Build from committed files, not the user's untracked files or local secrets.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
VERSION=$(sed -n "s/.*echo 'orphan-cleanup \([^']*\)'.*/\1/p" lib/cli.sh)
[ -n "$VERSION" ] || exit 1
mkdir -p dist
NAME="orphan-cleanup-$VERSION"
TEMP=$(mktemp -d "$ROOT/dist/.package.XXXXXX")
trap 'rm -rf "$TEMP"' EXIT
git archive --format=tar --prefix="$NAME/" HEAD | gzip -n > "$TEMP/$NAME.tar.gz"
(cd "$TEMP" && shasum -a 256 "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
mv "$TEMP/$NAME.tar.gz" "dist/$NAME.tar.gz"
mv "$TEMP/$NAME.tar.gz.sha256" "dist/$NAME.tar.gz.sha256"
printf '%s\n' "$ROOT/dist/$NAME.tar.gz"
