#!/bin/bash
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d) || exit 1
CHILD=
finish() { if [ -n "$CHILD" ]; then kill -TERM "$CHILD" 2>/dev/null || :; wait "$CHILD" 2>/dev/null || :; fi; rm -rf "$TMP"; }
trap finish EXIT
trap 'exit 1' INT TERM
export HOME="$TMP/home" LOGFILE="$TMP/cleanup.log"
mkdir "$HOME"
. "$ROOT/lib/core.sh"
PASS=0
fail() { echo "FAIL: $*" >&2; exit 1; }
eq() { [ "$1" = "$2" ] || fail "$3: expected [$2], got [$1]"; PASS=$((PASS + 1)); }
status() { local expected=$1; shift; "$@" > "$TMP/out" 2> "$TMP/err"; local got=$?; eq "$got" "$expected" "$*"; }
contains() { grep -q "$1" "$TMP/out" || fail "missing output $1"; PASS=$((PASS + 1)); }
[ "${1:-}" != --assertion-failure ] || eq wrong right 'intentional failure'
status 1 /bin/bash "$0" --assertion-failure
OC_UID=501 OC_SELF=900 OC_EXCLUDED=' 1 900 901 ' OC_MIN_SECONDS=10800
record() { printf '%s\t%s\t%s\tMon Oct 19 12:00:00 2026\t%s\t%s\t%s\t%s\n' "$1" "${2:-501}" "${3:-1}" "${4:-03:00:00}" "${5:-1024}" "${6:-/usr/local/bin/node}" "${7:-/usr/local/bin/node /tmp/godot-mcp/build/index.js}"; }
BASE=$(record 100)
for pair in '03:00 180' '03:00:00 10800' '1-02:03:04 93784' '00:00 0' '02:59:59 10799' '03:00:01 10801'; do
    eq "$(oc_elapsed "${pair% *}")" "${pair##* }" elapsed
done
for bad in '' abc 1:2 60:00 01:60 1-24:00:00 1-01:60:00 1:00:99 9999999999:00:00; do status 1 oc_elapsed "$bad"; done
for n in 1 3 48 8760 0003; do status 0 oc_age_hours "$n"; done
for n in 0 -1 1.5 abc '' 8761 999999999999999; do status 1 oc_age_hours "$n"; done
class() { local p u pp st el rs ex cm; IFS=$'\t' read -r p u pp st el rs ex cm <<< "$1"; oc_classify "$p" "$u" "$pp" "$st" "$el" "$rs" "$ex" "$cm"; eq "$OC_REASON" "$2" classification; }
class "$BASE" eligible
class "$(printf '%s' "$BASE" | sed 's/Mon Oct 19 12:00:00 2026/Mon Xxx 99 99:99:99 0000/')" invalid_metadata
class "$(record 100 501 1 03:00:00 20 /usr/bin/node '/usr/bin/node /tmp/godot-mcp/build/index.js other-script')" ambiguous_command
class "$(record 100 501 1 02:59:59)" too_young
class "$(record 100 501 1 03:00:01)" eligible
class "$(record 100 501 55)" parent_not_pid_1
class "$(record 100 502)" other_uid
class "$(record 900)" excluded_identity
class "$(record 901)" excluded_identity
class "$(record 1)" excluded_identity
class "$(record 100 501 1 bad)" invalid_metadata
class "$(record 100 501 1 03:00:00 bad)" invalid_metadata
class "$(record 100 501 1 03:00:00 20 /bin/sh '/bin/sh -c node /tmp/godot-mcp/build/index.js')" ambiguous_command
class "$(record 100 501 1 03:00:00 20 /usr/bin/node '/usr/bin/node --eval /tmp/godot-mcp/build/index.js')" ambiguous_command
class "$(record 100 501 1 03:00:00 20 /usr/bin/node '/usr/bin/node /tmp/other/index.js')" unmatched
class "$(record 100 501 1 03:00:00 20 /Applications/Google '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless=new')" ambiguous_command
class "$(record 100 501 1 03:00:00 20 /usr/bin/Chrome '/usr/bin/Chrome --headless=new')" ambiguous_command
class "$(record 100 501 1 00:03 20 /usr/bin/Chrome '/usr/bin/Chrome --headless')" ambiguous_command
class "$(record 100 501 1 03:00:00 20 /usr/bin/Chrome '/usr/bin/Chrome --user-data-dir=--headless=new')" ambiguous_command
class "$(record 100 501 1 03:00:00 20 /usr/bin/Chrome '/usr/bin/Chrome --normal')" unmatched
class "$(record 100 501 1 03:00:00 20 /usr/bin/node '/usr/bin/node /tmp/path with spaces/godot-mcp/build/index.js')" ambiguous_command
OC_MIN_SECONDS=172800; class "$(record 100 501 1 1-02:00:00)" too_young; OC_MIN_SECONDS=10800
# Exercise production collection/lookup through controlled ps output.
PS_FILE="$TMP/ps.txt"
ps() { cat "$PS_FILE"; }
printf '%s\n' '100 501 1 Mon Oct 19 12:00:00 2026 03:00:00 1024 /usr/local/bin/node /usr/local/bin/node /tmp/godot-mcp/build/index.js' > "$PS_FILE"
eq "$(oc_collect)" "$BASE" 'production collection normalization'
status 0 oc_lookup 100
status 3 oc_lookup 999
printf '%s\n' '100 501 truncated' > "$PS_FILE"
status 1 oc_collect
status 1 oc_lookup 100
unset -f ps
# Preserve production seams for the guarded integration and collector tests.
eval "$(declare -f oc_signal | sed '1s/oc_signal/production_signal/')"
eval "$(declare -f oc_lookup | sed '1s/oc_lookup/production_lookup/')"
# Fixtures replace all OS-facing operations; signal seam records only.
SIGNALS="$TMP/signals"; : > "$SIGNALS"
oc_signal() { printf '%s\n' "$1" >> "$SIGNALS"; [ "$SCENARIO" != signal_error ]; }
oc_pause() { :; }
oc_lookup() {
    case "$SCENARIO" in
        disappeared) return 3 ;;
        collection_error) return 1 ;;
        post_collection_error) if grep -qx "$1" "$SIGNALS"; then return 1; else record "$1"; fi ;;
        post_identity) if grep -qx "$1" "$SIGNALS"; then record "$1" | sed 's/12:00:00/13:00:00/'; else record "$1"; fi ;;
        uid) record "$1" 502 ;;
        parent) record "$1" 501 99 ;;
        age) record "$1" 501 1 00:01 ;;
        start) record "$1" | sed 's/12:00:00/13:00:00/' ;;
        command) record "$1" 501 1 03:00:00 10 /usr/local/bin/node '/usr/local/bin/node /new/godot-mcp/build/index.js' ;;
        success|rss|partial)
            if grep -qx "$1" "$SIGNALS"; then
                if [ "$SCENARIO" = partial ] && [ "$1" = 101 ]; then record "$1"; else return 3; fi
            elif [ "$SCENARIO" = rss ]; then record "$1" 501 1 03:00:00 9999
            else record "$1"; fi ;;
        *) record "$1" ;;
    esac
}
status 0 oc_scan "$BASE"; contains 'Candidates: 1'; contains 'not measured RAM freed'
status 0 oc_scan ''; contains 'Candidates: 0'
eq "$(cat "$SIGNALS")" '' 'scan cannot signal'
[ ! -e "$LOGFILE" ] || fail 'scan wrote log'
SCENARIO=success
status 1 oc_cleanup godot-mcp "$BASE" 100 101
eq "$(cat "$SIGNALS")" '' 'invalid full set cannot signal'
status 2 oc_cleanup godot-mcp "$BASE" 100 100
OC_UID=0; status 2 oc_cleanup godot-mcp "$BASE" 100; OC_UID=501
for scenario in uid parent age start command collection_error; do
    SCENARIO=$scenario; : > "$SIGNALS"
    status 1 oc_cleanup godot-mcp "$BASE" 100
    eq "$(cat "$SIGNALS")" '' "$scenario prevented signal"
done
SCENARIO=disappeared; status 0 oc_cleanup godot-mcp "$BASE" 100; contains disappeared_before_signal
SCENARIO=signal_error; : > "$SIGNALS"; status 1 oc_cleanup godot-mcp "$BASE" 100; contains signal_error
eq "$(cat "$SIGNALS")" 100 'one attempted signal'
SCENARIO=survivor; : > "$SIGNALS"; status 1 oc_cleanup godot-mcp "$BASE" 100; contains still_running
for SCENARIO in success rss; do
    : > "$SIGNALS"; status 0 oc_cleanup godot-mcp "$BASE" 100; contains confirmed_exit
    eq "$(cat "$SIGNALS")" 100 'exact chosen PID once'
done
for SCENARIO in post_collection_error post_identity; do
    : > "$SIGNALS"; status 1 oc_cleanup godot-mcp "$BASE" 100
    eq "$(cat "$SIGNALS")" 100 'post-signal failure never resends'
done
SCENARIO=partial; : > "$SIGNALS"; TWO=$(printf '%s\n%s' "$BASE" "$(record 101)")
status 1 oc_cleanup godot-mcp "$TWO" 100 101; contains 'confirmed_exits=1'; contains 'survivors=1'
LOGFILE="$TMP/missing/log"; : > "$SIGNALS"; status 1 oc_cleanup godot-mcp "$BASE" 100
eq "$(cat "$SIGNALS")" '' 'unwritable log prevents signal'
LOGFILE="$TMP/cleanup.log"
eval "$(declare -f oc_log | sed '1s/oc_log/original_log/')"
oc_log() { return 1; }
: > "$SIGNALS"; status 1 oc_cleanup godot-mcp "$BASE" 100
eq "$(cat "$SIGNALS")" '' 'log write failure prevents signal'
oc_log() { original_log "$@"; }
grep -q '/tmp/godot-mcp' "$LOGFILE" && fail 'command leaked to log'
# Public CLI is always read-only; invoke with an isolated HOME.
for args in '' scan --dry-run -n '--min-age-hours 48' '--profile godot-mcp' --verbose --help; do
    # Intentional splitting of fixed test cases, never user input.
    status 0 /bin/bash "$ROOT/cleanup_orphan_processes.sh" $args
done
for args in '3' clean '--min-age-hours 0' '--min-age-hours 8761' '--min-age-hours 1.5' '--min-age-hours 3 --min-age-hours 4' '--profile bad' '--profile' '--bad'; do
    status 2 /bin/bash "$ROOT/cleanup_orphan_processes.sh" $args
done
[ ! -e "$HOME/cleanup_orphan_processes.log" ] || fail 'public scan wrote log'
# Required collection failure and unsupported platform, without touching real processes.
mkdir "$TMP/bin"
printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/ps"; chmod +x "$TMP/bin/ps"
status 1 env PATH="$TMP/bin:$PATH" /bin/bash "$ROOT/cleanup_orphan_processes.sh"
printf '#!/bin/sh\necho Linux\n' > "$TMP/bin/uname"; chmod +x "$TMP/bin/uname"
status 2 env PATH="$TMP/bin:$PATH" /bin/bash "$ROOT/cleanup_orphan_processes.sh"
# No optional memory diagnostic is invoked; its absence cannot break scans.
printf '#!/bin/sh\nexit 99\n' > "$TMP/bin/memory_pressure"; chmod +x "$TMP/bin/memory_pressure"
rm "$TMP/bin/ps" "$TMP/bin/uname"
status 0 env PATH="$TMP/bin:$PATH" /bin/bash "$ROOT/cleanup_orphan_processes.sh"
# Integration: only a child created here can receive a real signal. Synthetic
# metadata replaces eligibility, not the production policy. No ambient selection.
/bin/sleep 30 & CHILD=$!
BASE=$(record "$CHILD")
oc_lookup() {
    [ "$1" = "$CHILD" ] || return 1
    if kill -0 "$CHILD" 2>/dev/null; then record "$CHILD"; else return 3; fi
}
oc_signal() { [ "$1" = "$CHILD" ] && production_signal "$1"; }
oc_pause() { sleep 1; }
status 0 oc_cleanup godot-mcp "$BASE" "$CHILD"
contains confirmed_exit
wait "$CHILD" 2>/dev/null || :
CHILD=
printf 'PASS: %s assertions; Bash %s; isolated fixtures and disposable-child integration.\n' "$PASS" "$BASH_VERSION"
