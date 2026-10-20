#!/bin/bash
# Read-only public entrypoint. Cleanup UI is intentionally deferred to M2.
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
. "$ROOT/lib/core.sh"
usage() {
    cat <<'HELP'
macOS Orphan Process Cleanup — milestone 1 safety preview
Usage: ./cleanup_orphan_processes.sh [scan] [--dry-run|-n]
       [--min-age-hours N] [--profile godot-mcp|headless-chrome] [--verbose]
       ./cleanup_orphan_processes.sh --help
Default: read-only scan, both profiles, minimum age 3 hours (N: 1..8760).
No signals or log files are produced. Public cleanup arrives in milestone 2.
Age and PPID 1 do not prove inactivity. RSS is not measured RAM freed.
Verbose output can reveal secrets in full commands; redact before sharing.
HELP
}
mode= age=3 profile= verbose=0 age_seen=0 dry_seen=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) [ "$#" -eq 1 ] && [ -z "$mode$profile" ] && [ "$age_seen$verbose$dry_seen" = 000 ] || exit 2; usage; exit 0 ;;
        scan) [ -z "$mode" ] || exit 2; mode=scan ;;
        --dry-run|-n) [ "$dry_seen" -eq 0 ] || exit 2; dry_seen=1 ;;
        --verbose) [ "$verbose" -eq 0 ] || exit 2; verbose=1 ;;
        --min-age-hours)
            [ "$#" -ge 2 ] && [ "$age_seen" -eq 0 ] && oc_age_hours "$2" || { echo 'Invalid minimum age; use 1..8760.' >&2; exit 2; }
            age=$2; age_seen=1; shift ;;
        --profile)
            [ "$#" -ge 2 ] && [ -z "$profile" ] || exit 2
            case "$2" in godot-mcp|headless-chrome) profile=$2 ;; *) exit 2 ;; esac; shift ;;
        *) echo 'Unsupported invocation. Use scan --min-age-hours N; cleanup is not yet exposed.' >&2; exit 2 ;;
    esac
    shift
done
[ "$(uname -s)" = Darwin ] || { echo 'macOS required.' >&2; exit 2; }
OC_MIN_SECONDS=$((10#$age * 3600))
oc_init || { echo 'Cannot determine process ancestry.' >&2; exit 1; }
snapshot=$(oc_collect) || { echo 'Cannot collect processes.' >&2; exit 1; }
[ "$verbose" -eq 0 ] || echo 'Warning: full command lines may contain secrets.' >&2
oc_scan "$snapshot" "$profile" "$verbose"
