#!/bin/bash
# User-local installation; no scheduler, privilege escalation, or runtime execution.
set -eu
umask 022
fail() { printf 'install: %s\n' "$*" >&2; exit 1; }
prefix=${HOME:?HOME must be set}/.local
uninstall=0
while [ "$#" -gt 0 ]; do
    case $1 in
        --prefix) [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--prefix needs a path'; prefix=$2; shift 2 ;;
        --uninstall) uninstall=1; shift ;;
        --help|-h) echo 'Usage: install.sh [--prefix PATH] [--uninstall]'; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
case $prefix in /*) ;; *) prefix=$PWD/$prefix ;; esac
# Reject symlinks in every ancestor, including dangling symlinks.
check_path() {
    local path=$1
    while [ "$path" != / ]; do
        [ ! -L "$path" ] || fail "Symlink refused: $path"
        path=$(dirname -- "$path")
    done
}
check_path "$prefix"
# Normalize only after checking the supplied path (including .. components).
if [ "$uninstall" -eq 0 ]; then mkdir -p -- "$prefix"; fi
[ -e "$prefix" ] || exit 0
prefix=$(CDPATH='' cd -- "$prefix" && pwd -P) || exit 1
bin=$prefix/bin
base=$prefix/libexec
runtime=$base/orphan-cleanup
launcher=$bin/orphan-cleanup
for path in "$bin" "$base" "$runtime" "$launcher"; do check_path "$path"; done
for path in "$bin" "$base"; do
    [ ! -e "$path" ] || [ -d "$path" ] || fail "Not a directory: $path"
done
launcher_text() {
    cat <<'LAUNCHER'
#!/bin/bash
# orphan-cleanup owned launcher v1
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../libexec/orphan-cleanup" && pwd) || exit 1
exec /bin/bash "$ROOT/orphan-cleanup" "$@"
LAUNCHER
}
files='orphan-cleanup cleanup_orphan_processes.sh lib/core.sh lib/cli.sh'
# A marker alone is not ownership: verify exact inventory and recorded checksums.
validate_runtime() {
    [ -d "$runtime" ] && [ -O "$runtime" ] || fail 'Unowned runtime directory'
    [ ! -L "$runtime/.owned" ] && [ -f "$runtime/.owned" ] || fail 'Missing ownership manifest'
    [ "$(find "$runtime" -type l -print | wc -l | tr -d ' ')" = 0 ] || fail 'Runtime symlink refused'
    [ "$(find "$runtime" -mindepth 1 -print | wc -l | tr -d ' ')" = 6 ] || fail 'Unexpected runtime contents'
    [ -d "$runtime/lib" ] || fail 'Missing runtime library'
    local actual file
    for file in $files; do
        [ -f "$runtime/$file" ] && [ -O "$runtime/$file" ] || fail 'Invalid runtime file'
    done
    actual=$(cd "$runtime"; printf '%s\n' 'orphan-cleanup installation v1'; cksum $files) || fail 'Invalid runtime'
    [ "$(cat "$runtime/.owned")" = "$actual" ] || fail 'Runtime ownership mismatch'
}
if [ -e "$runtime" ]; then validate_runtime; fi
if [ -e "$launcher" ]; then
    [ -f "$launcher" ] && [ -O "$launcher" ] || fail 'Unowned launcher'
    [ "$(cat "$launcher")" = "$(launcher_text)" ] || fail 'Unrelated launcher refused'
fi
if [ "$uninstall" -eq 1 ]; then
    if [ -e "$launcher" ]; then rm -- "$launcher"; fi
    if [ -e "$runtime" ]; then
        for file in $files .owned; do rm -- "$runtime/$file"; done
        rmdir -- "$runtime/lib" "$runtime"
    fi
    echo 'Uninstalled; logs preserved.'
    exit 0
fi
source_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
mkdir -p -- "$bin" "$base"
stage=$(mktemp -d "$base/.orphan-cleanup.XXXXXX")
launch_stage=''
old=0
new=0
committed=0
finish() {
    if [ "$committed" -eq 0 ]; then
        if [ "$new" -eq 1 ]; then
            for file in $files .owned; do rm -f -- "$runtime/$file"; done
            rmdir -- "$runtime/lib" "$runtime"
        fi
        if [ "$old" -eq 1 ]; then mv -- "$stage/previous" "$runtime"; fi
    fi
    [ -z "$launch_stage" ] || rm -f -- "$launch_stage"
    # Only this invocation's private staging tree is recursively removed.
    rm -rf -- "$stage"
}
trap finish EXIT
trap 'exit 1' HUP INT TERM
mkdir "$stage/lib"
for file in $files; do cp -- "$source_root/$file" "$stage/$file"; done
chmod 755 "$stage/orphan-cleanup" "$stage/cleanup_orphan_processes.sh"
(cd "$stage"; printf '%s\n' 'orphan-cleanup installation v1'; cksum $files) > "$stage/.owned"
launch_stage=$(mktemp "$bin/.orphan-cleanup.XXXXXX")
launcher_text > "$launch_stage"
chmod 755 "$launch_stage"
# Keep the old tree until the launcher has been published successfully.
mkdir "$stage/next"
for file in orphan-cleanup cleanup_orphan_processes.sh lib .owned; do mv -- "$stage/$file" "$stage/next/$file"; done
if [ -e "$runtime" ]; then mv -- "$runtime" "$stage/previous"; old=1; fi
mv -- "$stage/next" "$runtime"; new=1
mv -f -- "$launch_stage" "$launcher"; launch_stage=''
committed=1
printf 'Installed orphan-cleanup in %s\nAdd %s to PATH.\n' "$prefix" "$bin"
