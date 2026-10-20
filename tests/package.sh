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
# A failed archive must not replace an existing artifact or checksum.
mkdir "$TMP/mock"
printf '#!/bin/sh\nexit 77\n' > "$TMP/mock/git"
chmod +x "$TMP/mock/git"
before=$(shasum -a 256 "$ROOT/dist/orphan-cleanup-0.2.0.tar.gz")
if PATH="$TMP/mock:$PATH" /bin/bash "$ROOT/scripts/package.sh"; then
    echo 'Packaging incorrectly accepted git archive failure' >&2; exit 1
fi
[ "$(shasum -a 256 "$ROOT/dist/orphan-cleanup-0.2.0.tar.gz")" = "$before" ]
echo 'PASS: packaging failure preserves existing artifact.'
