#!/bin/bash
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT/dist"
shasum -a 256 -c orphan-cleanup-0.2.0.tar.gz.sha256
tar -xzf orphan-cleanup-0.2.0.tar.gz -C "$TMP"
TMP=$(CDPATH='' cd -- "$TMP" && pwd -P)
export HOME="$TMP/home"
mkdir "$HOME"
/bin/bash "$TMP/orphan-cleanup-0.2.0/install.sh" --prefix "$TMP/installed package"
[ "$("$TMP/installed package/bin/orphan-cleanup" --version)" = 'orphan-cleanup 0.2.0' ]
"$TMP/installed package/bin/orphan-cleanup" --help >/dev/null
/bin/bash "$TMP/orphan-cleanup-0.2.0/install.sh" --prefix "$TMP/installed package" --uninstall
/bin/bash "$TMP/orphan-cleanup-0.2.0/tests/install.sh"
printf 'PASS: archive checksum, extraction, installation, version/help and uninstall.\n'
