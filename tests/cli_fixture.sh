#!/bin/bash
# Test harness only: never calls the real signal function or exposes a test flag
# in production. Exercise the actual shared CLI with explicit function seams.
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/lib/core.sh"
. "$ROOT/lib/cli.sh"
oc_init() { OC_UID=501; OC_EXCLUDED=' 1 900 '; [ "${SCENARIO:-}" != root ] || OC_UID=0; }
fixture_row() { printf '%s\t501\t1\tMon Oct 19 12:00:00 2026\t03:00:00\t1024\t/usr/bin/node\t/usr/bin/node /tmp/godot-mcp/build/index.js\n' "$1"; }
oc_collect() {
    case "${SCENARIO:-}" in
        collection_error) return 1 ;;
        empty) return 0 ;;
    esac
    fixture_row 100; fixture_row 101
    printf '102\t501\t1\tMon Oct 19 12:00:00 2026\t03:00:00\t2048\t/Applications/Google\t/Applications/Google Chrome --headless=new SECRET_TOKEN\n'
}
oc_lookup() {
    if [ "${SCENARIO:-}" = prompt_change ] && [ "$1" = 101 ] && [ -e "$SIGNAL_RECORDER.change" ]; then fixture_row "$1" | sed 's/12:00:00/13:00:00/'
    elif [ "${SCENARIO:-}" = changed ]; then fixture_row "$1" | sed 's/12:00:00/13:00:00/'
    elif grep -qx "$1" "$SIGNAL_RECORDER"; then return 3
    else fixture_row "$1"; fi
}
oc_signal() { printf '%s\n' "$1" >> "$SIGNAL_RECORDER"; }
oc_pause() { :; }
oc_main "$@"
