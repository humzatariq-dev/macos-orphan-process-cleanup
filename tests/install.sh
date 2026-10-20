#!/bin/bash
# No ambient process collection or cleanup: all OS process queries are synthetic.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/orphan-install.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT
TMP=$(CDPATH='' cd -- "$TMP" && pwd -P)
export HOME="$TMP/home space"
mkdir -p "$HOME" "$TMP/mock"
export LOGFILE="$HOME/cleanup_orphan_processes.log"
printf 'preserve logs\n' > "$LOGFILE"
cat > "$TMP/mock/ps" <<'PS'
#!/bin/bash
case " $* " in
    *' -axo '*) exit 0 ;;
    *) echo 1 ;;
esac
PS
cat > "$TMP/mock/uname" <<'UNAME'
#!/bin/bash
echo Darwin
UNAME
chmod +x "$TMP/mock/ps" "$TMP/mock/uname"
export PATH="$TMP/mock:/usr/bin:/bin:/usr/sbin:/sbin"
install() { /bin/bash "$ROOT/install.sh" "$@"; }
refuse() { if install "$@" > "$TMP/refusal" 2>&1; then echo 'Expected refusal' >&2; exit 1; fi; }
prefix="$HOME/.local"
install
version=$("$prefix/bin/orphan-cleanup" --version)
source_version=$("$ROOT/orphan-cleanup" --version)
[ "$version" = "$source_version" ]
case $version in 'orphan-cleanup 0.2.0'|'orphan-cleanup 0.2.0-dev') ;; *) exit 1 ;; esac
"$prefix/bin/orphan-cleanup" scan > "$TMP/scan"
install
"$prefix/bin/orphan-cleanup" --version > /dev/null
install --uninstall
install --uninstall
[ ! -e "$prefix/bin/orphan-cleanup" ]
[ ! -e "$prefix/libexec/orphan-cleanup" ]
[ "$(cat "$LOGFILE")" = 'preserve logs' ]
prefix="$TMP/custom prefix"
mkdir -p "$prefix/bin"
printf '#!/bin/bash\necho unrelated\n' > "$prefix/bin/orphan-cleanup"
chmod +x "$prefix/bin/orphan-cleanup"
refuse --prefix "$prefix"
refuse --prefix "$prefix" --uninstall
[ "$("$prefix/bin/orphan-cleanup")" = unrelated ]
rm "$prefix/bin/orphan-cleanup"
mkdir -p "$prefix/libexec/orphan-cleanup"
echo unrelated > "$prefix/libexec/orphan-cleanup/keep"
refuse --prefix "$prefix"
refuse --prefix "$prefix" --uninstall
[ "$(cat "$prefix/libexec/orphan-cleanup/keep")" = unrelated ]
rm "$prefix/libexec/orphan-cleanup/keep"
rmdir "$prefix/libexec/orphan-cleanup"
ln -s "$HOME" "$prefix/libexec/orphan-cleanup"
refuse --prefix "$prefix"
refuse --prefix "$prefix" --uninstall
rm "$prefix/libexec/orphan-cleanup"
ln -s "$TMP/missing" "$prefix/bin/orphan-cleanup"
refuse --prefix "$prefix"
refuse --prefix "$prefix" --uninstall
rm "$prefix/bin/orphan-cleanup"
install --prefix "$prefix"
echo extra > "$prefix/libexec/orphan-cleanup/extra"
refuse --prefix "$prefix"
refuse --prefix "$prefix" --uninstall
rm "$prefix/libexec/orphan-cleanup/extra"
mv "$prefix/libexec/orphan-cleanup/lib/core.sh" "$TMP/core"
ln -s "$TMP/core" "$prefix/libexec/orphan-cleanup/lib/core.sh"
refuse --prefix "$prefix"
refuse --prefix "$prefix" --uninstall
rm "$prefix/libexec/orphan-cleanup/lib/core.sh"
mv "$TMP/core" "$prefix/libexec/orphan-cleanup/lib/core.sh"
install --prefix "$prefix"
# Inject TERM immediately after either runtime rename; previous installation
# must survive regardless of shell assignment timing.
for boundary in previous next; do
    cat > "$TMP/mock/mv" <<'MV'
#!/bin/bash
/bin/mv "$@" || exit
case "$INTERRUPT_BOUNDARY:$*" in
    previous:*'/previous'|next:*'/next '*'/libexec/orphan-cleanup') kill -TERM "$PPID" ;;
esac
MV
    chmod +x "$TMP/mock/mv"
    export INTERRUPT_BOUNDARY=$boundary
    refuse --prefix "$prefix"
    [ "$("$prefix/bin/orphan-cleanup" --version)" = "$source_version" ]
    rm "$TMP/mock/mv"
done
install --prefix "$prefix" --uninstall
install --prefix "$prefix" --uninstall
[ "$(cat "$LOGFILE")" = 'preserve logs' ]
echo 'PASS installer lifecycle, scan, upgrade, conflicts, symlinks, logs, repeated uninstall'
