# Shared Bash 3.2 CLI. Safe to source: only defines functions.
oc_usage() {
    cat <<'HELP'
orphan-cleanup 0.2.0 — inspect leftover developer processes on macOS
Usage: orphan-cleanup [scan] [--profile godot-mcp|headless-chrome]
                     [--min-age-hours N] [--verbose]
       orphan-cleanup clean --profile godot-mcp|headless-chrome
                     --pid PID [--pid PID ...] [--min-age-hours N] [--yes]
       orphan-cleanup --help | --version
Default: read-only scan, both profiles, minimum age 3 hours (N: 1..8760).
-n / --dry-run: scan aliases; cannot combine with clean.
--verbose: scan only; full commands may contain secrets. Redact before sharing.
--pid: explicit PID > 1, repeat to select; cleanup validates the entire set.
--yes: cleanup only; skips the TTY prompt, never safety checks or preview.
Cleanup requires exact 'yes' on a TTY unless --yes is explicitly supplied.
Chrome is report-only. Godot eligibility does not prove inactivity.
SIGTERM can interrupt useful work. No SIGKILL or process-tree termination.
Cleanup log: ~/cleanup_orphan_processes.log (override LOGFILE); no full commands.
Scans/help/version write no log. RSS estimates are not measured RAM freed.
Exit: 0 success/cancellation; 1 operational/selection failure; 2 invalid invocation,
unsupported platform, root cleanup, or non-TTY cleanup without --yes.
Legacy numeric age: use 'orphan-cleanup scan --min-age-hours N' instead.
HELP
}
oc_cli_error() { printf '%s\n' "$*" >&2; return 2; }
oc_tty() { [ -t 0 ] && [ -t 1 ]; }
oc_main() {
    local mode='' age=3 profile='' verbose=0 age_seen=0 dry_seen=0 yes=0
    local pids=() seen=' ' pid snapshot selected='' row answer
    if [ "$#" -eq 1 ]; then
        case "$1" in --help|-h) oc_usage; return 0 ;; --version) echo 'orphan-cleanup 0.2.0'; return 0 ;; esac
    fi
    while [ "$#" -gt 0 ]; do
        case "$1" in
            scan|clean) [ -z "$mode" ] || { oc_cli_error 'Choose exactly one command.'; return 2; }; mode=$1 ;;
            --dry-run|-n) [ "$dry_seen" -eq 0 ] || return 2; dry_seen=1 ;;
            --verbose) [ "$verbose" -eq 0 ] || return 2; verbose=1 ;;
            --yes) [ "$yes" -eq 0 ] || return 2; yes=1 ;;
            --min-age-hours)
                [ "$#" -ge 2 ] && [ "$age_seen" -eq 0 ] && oc_age_hours "$2" || { oc_cli_error 'Minimum age must be 1..8760, specified once.'; return 2; }
                age=$2; age_seen=1; shift ;;
            --profile)
                [ "$#" -ge 2 ] && [ -z "$profile" ] || return 2
                case "$2" in godot-mcp|headless-chrome) profile=$2 ;; *) oc_cli_error 'Unknown profile.'; return 2 ;; esac; shift ;;
            --pid)
                [ "$#" -ge 2 ] && oc_uint "$2" && [ "$2" -gt 1 ] || return 2
                pid=$((10#$2))
                case "$seen" in *" $pid "*) oc_cli_error 'Duplicate PID.'; return 2 ;; esac
                seen="$seen$pid "; pids[${#pids[@]}]=$pid; shift ;;
            *) oc_cli_error 'Unsupported invocation. Use scan --min-age-hours N; see --help.'; return 2 ;;
        esac
        shift
    done
    mode=${mode:-scan}
    if [ "$mode" = clean ]; then
        [ "$dry_seen" -eq 0 ] && [ "$verbose" -eq 0 ] && [ -n "$profile" ] && [ "${#pids[@]}" -gt 0 ] || { oc_cli_error 'Cleanup requires one profile and explicit PIDs; no dry-run/verbose.'; return 2; }
    else
        [ "$yes" -eq 0 ] && [ "${#pids[@]}" -eq 0 ] || return 2
    fi
    [ "$(uname -s)" = Darwin ] || { oc_cli_error 'macOS required.'; return 2; }
    # Shared with classification in core.sh.
    # shellcheck disable=SC2034
    OC_MIN_SECONDS=$((10#$age * 3600))
    oc_init || { echo 'Cannot determine process ancestry.' >&2; return 1; }
    if [ "$mode" = clean ]; then
        [ "$OC_UID" -ne 0 ] || { oc_cli_error 'Root cleanup is refused; do not use sudo.'; return 2; }
        [ "$yes" -eq 1 ] || oc_tty || { oc_cli_error 'Non-TTY cleanup requires explicit --yes.'; return 2; }
    fi
    snapshot=$(oc_collect) || { echo 'Cannot collect processes.' >&2; return 1; }
    if [ "$mode" = scan ]; then
        [ "$verbose" -eq 0 ] || echo 'Warning: full command lines may contain secrets.' >&2
        oc_scan "$snapshot" "$profile" "$verbose"; return $?
    fi
    # Complete-set validation and selection-specific preview before prompting.
    for pid in "${pids[@]}"; do
        row=$(printf '%s\n' "$snapshot" | awk -F '\t' -v pid="$pid" '$1==pid {print; n++} END {if(n!=1)exit 1}') || { echo "PID $pid absent or ambiguous; nothing signalled." >&2; return 1; }
        oc_record_eligible "$row" "$profile" || { echo "PID $pid ineligible for $profile; nothing signalled." >&2; return 1; }
        selected="${selected}${row}"$'\n'
    done
    echo 'Selected cleanup preview (eligibility is not proof of inactivity):'
    oc_scan "$selected" "$profile" 0
    if [ "$yes" -eq 0 ]; then
        printf "Send SIGTERM to selected PIDs? Type exactly 'yes': "
        IFS= read -r answer || answer=
        if [ "$answer" != yes ]; then echo 'Cancelled. No processes terminated.'; return 0; fi
    fi
    oc_cleanup "$profile" "$snapshot" "${pids[@]}"
}
