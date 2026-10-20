# Bash 3.2 safety core. Sourcing defines functions only; never executes cleanup.
export LC_ALL=C

oc_uint() { [[ $1 =~ ^[0-9]+$ ]] && [ ${#1} -le 9 ]; }
oc_age_hours() { oc_uint "$1" && [ "$1" -ge 1 ] && [ "$1" -le 8760 ]; }
oc_elapsed() {
    local value=$1 days=0 hours=0 minutes seconds
    if [[ $value =~ ^([0-9]+)-([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
        days=${BASH_REMATCH[1]}; hours=${BASH_REMATCH[2]}; minutes=${BASH_REMATCH[3]}; seconds=${BASH_REMATCH[4]}
        oc_uint "$days" || return 1
        [ "$((10#$hours))" -lt 24 ] || return 1
    elif [[ $value =~ ^([0-9]+):([0-9]{2}):([0-9]{2})$ ]]; then
        hours=${BASH_REMATCH[1]}; minutes=${BASH_REMATCH[2]}; seconds=${BASH_REMATCH[3]}
        oc_uint "$hours" || return 1
    elif [[ $value =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
        minutes=${BASH_REMATCH[1]}; seconds=${BASH_REMATCH[2]}
    else
        return 1
    fi
    [ "$((10#$minutes))" -lt 60 ] && [ "$((10#$seconds))" -lt 60 ] || return 1
    printf '%s\n' "$((10#$days * 86400 + 10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds))"
}

# Snapshot TSV: pid uid ppid start etime rss executable command.
# comm is separate from args; neither is treated as an argv serialization.
oc_collect() {
    local raw
    raw=$(ps -ww -axo pid=,uid=,ppid=,lstart=,etime=,rss=,comm=,args=) || return 1
    printf '%s\n' "$raw" | awk '
    NF == 0 {next}
    NF < 12 {bad=1; next}
    NF >= 12 {
        start=$4 " " $5 " " $6 " " $7 " " $8
        # comm can contain spaces. Such paths remain ambiguous/report-only.
        command=$12; for(i=13;i<=NF;i++) command=command " " $i
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",$1,$2,$3,start,$9,$10,$11,command
    }
    END {if(bad)exit 1}'
}

oc_init() {
    OC_UID=$(id -u) || return 1
    OC_SELF=$$
    OC_EXCLUDED=" 1 $$ "
    local parent=$$ next count=0
    while [ "$parent" -gt 1 ] && [ "$count" -lt 128 ]; do
        next=$(ps -p "$parent" -o ppid=) || return 1
        next=${next//[[:space:]]/}
        oc_uint "$next" && [ "$next" -gt 0 ] && [ "$next" != "$parent" ] || return 1
        OC_EXCLUDED="$OC_EXCLUDED$next "
        parent=$next; count=$((count + 1))
    done
    [ "$parent" -eq 1 ]
}

oc_classify() {
    local pid=$1 uid=$2 ppid=$3 start=$4 elapsed=$5 rss=$6 exe=$7 cmd=$8 age
    OC_PROFILE= OC_REASON=unmatched OC_SECONDS=0
    [ "$uid" = "$OC_UID" ] || { OC_REASON=other_uid; return; }
    case "$cmd" in
        *godot-mcp/build/index.js*) OC_PROFILE=godot-mcp ;;
        *--headless*) OC_PROFILE=headless-chrome ;;
        *) return ;;
    esac
    OC_REASON=invalid_metadata
    oc_uint "$pid" && oc_uint "$uid" && oc_uint "$ppid" && oc_uint "$rss" || return 0
    [ "$pid" -gt 0 ] && [ "$ppid" -gt 0 ] || return 0
    [[ $start =~ ^[A-Z][a-z]{2}\ [A-Z][a-z]{2}\ [0-9]{1,2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [0-9]{4}$ ]] || return 0
    local normalized
    normalized=$(date -j -f '%a %b %e %T %Y' "$start" '+%a %b %e %T %Y' 2>/dev/null) || return 0
    # Normalize ps/awk's collapsed day padding before exact round-trip check.
    normalized=$(printf '%s\n' "$normalized" | awk '{$1=$1; print}')
    [ "$normalized" = "$start" ] || return 0
    age=$(oc_elapsed "$elapsed") || return 0
    OC_SECONDS=$age
    case "$OC_EXCLUDED" in *" $pid "*) OC_REASON=excluded_identity; return ;; esac
    OC_REASON=ambiguous_command
    # Only an unambiguous no-whitespace argv prefix is eligible. Reject shell
    # quoting/escapes instead of evaluating or attempting to unescape commands.
    case "$cmd" in *\'*|*\"*|*\\*) return ;; esac
    local -a words
    local IFS=' '
    read -r -a words <<< "$cmd"
    [ "${words[0]:-}" = "$exe" ] || return 0
    case "$OC_PROFILE" in
        godot-mcp)
            [ "${exe##*/}" = node ] || return 0
            [ "${#words[@]}" -eq 2 ] || return 0
            case "${words[1]:-}" in */godot-mcp/build/index.js) ;; *) return ;; esac
            ;;
        headless-chrome)
            # Flattened ps text cannot distinguish a flag from whitespace
            # inside a single argument. All browser matches remain report-only
            # until a reliable argv collector exists; never infer boundaries.
            return 0 ;;
    esac
    if [ "$age" -lt "$OC_MIN_SECONDS" ]; then OC_REASON=too_young
    elif [ "$ppid" -ne 1 ]; then OC_REASON=parent_not_pid_1
    else OC_REASON=eligible
    fi
}

oc_scan() {
    local snapshot=$1 filter=${2:-} verbose=${3:-0} pid uid ppid start elapsed rss exe cmd count=0 total=0
    printf 'PID\tPROFILE\tAGE\tRSS_KiB\tPPID\tREASON\n'
    while IFS=$'\t' read -r pid uid ppid start elapsed rss exe cmd; do
        oc_classify "$pid" "$uid" "$ppid" "$start" "$elapsed" "$rss" "$exe" "$cmd"
        [ -n "$OC_PROFILE" ] && [ "$OC_REASON" != other_uid ] || continue
        [ -z "$filter" ] || [ "$filter" = "$OC_PROFILE" ] || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$OC_PROFILE" "$elapsed" "$rss" "$ppid" "$OC_REASON"
        [ "$verbose" -eq 0 ] || printf '  command: %s\n' "$cmd"
        if [ "$OC_REASON" = eligible ]; then count=$((count + 1)); total=$((total + 10#$rss)); fi
    done <<< "$snapshot"
    printf 'Candidates: %s; estimated candidate RSS: %s KiB (not measured RAM freed).\n' "$count" "$total"
    printf 'No processes terminated.\n'
}

# Overridable I/O seams for tests. No environment-based test bypass exists.
oc_lookup() {
    local snapshot line
    snapshot=$(oc_collect) || return 1
    line=$(printf '%s\n' "$snapshot" | awk -F '\t' -v pid="$1" '$1==pid {print; n++} END {if(n>1)exit 1}') || return 1
    [ -n "$line" ] || return 3
    printf '%s\n' "$line"
}
oc_signal() { kill -TERM "$1"; }
oc_pause() { sleep 1; }
oc_log() { printf '%s\n' "$*" >&3; }
oc_result() { printf '%s\t%s\n' "$1" "$2"; oc_log "$1 $2"; }
oc_identity() {
    local pid uid ppid start elapsed rss exe cmd
    IFS=$'\t' read -r pid uid ppid start elapsed rss exe cmd <<< "$1"
    printf '%s\t%s\t%s\t%s\n' "$pid" "$uid" "$start" "$cmd"
}
oc_record_eligible() {
    local pid uid ppid start elapsed rss exe cmd
    IFS=$'\t' read -r pid uid ppid start elapsed rss exe cmd <<< "$1"
    oc_classify "$pid" "$uid" "$ppid" "$start" "$elapsed" "$rss" "$exe" "$cmd"
    [ "$OC_REASON" = eligible ] && [ "$OC_PROFILE" = "$2" ]
}

# Internal core, not a public cleanup CLI. Caller must supply explicit selection
# after preview/confirmation (M2). Returns 2 misuse, 1 partial/failure, 0 success.
oc_cleanup() {
    local profile=$1 snapshot=$2; shift 2
    [ "$OC_UID" -ne 0 ] || return 2
    case "$profile" in godot-mcp|headless-chrome) ;; *) return 2 ;; esac
    [ "$#" -gt 0 ] || return 2
    local pid row seen=' ' rows=() status rc current i failed=0 confirmed=0 disappeared=0 survivors=0 skipped=0 errors=0 attempted=0
    # Validate complete requested set before opening log or signalling.
    for pid in "$@"; do
        oc_uint "$pid" && [ "$pid" -gt 1 ] || return 2
        case "$seen" in *" $pid "*) return 2 ;; esac
        seen="$seen$pid "
        row=$(printf '%s\n' "$snapshot" | awk -F '\t' -v pid="$pid" '$1==pid {print; n++} END {if(n!=1)exit 1}') || return 1
        oc_record_eligible "$row" "$profile" || return 1
        rows[${#rows[@]}]=$row
    done
    (umask 077; : >> "${LOGFILE:-$HOME/cleanup_orphan_processes.log}") || return 1
    exec 3>> "${LOGFILE:-$HOME/cleanup_orphan_processes.log}" || return 1
    oc_log 'Cleanup started; RSS estimates are not measured RAM freed.' || { exec 3>&-; return 1; }
    for row in "${rows[@]}"; do
        pid=${row%%$'\t'*}
        current=$(oc_lookup "$pid"); rc=$?
        status=
        if [ "$rc" -eq 3 ]; then status=disappeared_before_signal; disappeared=$((disappeared + 1))
        elif [ "$rc" -ne 0 ]; then status=collection_error; errors=$((errors + 1)); failed=1
        elif [ "$(oc_identity "$row")" != "$(oc_identity "$current")" ]; then status=identity_changed; skipped=$((skipped + 1)); failed=1
        elif ! oc_record_eligible "$current" "$profile"; then status=eligibility_changed; skipped=$((skipped + 1)); failed=1
        elif ! oc_log "$pid SIGTERM requested"; then status=logging_error; errors=$((errors + 1)); failed=1
        else
            attempted=$((attempted + 1))
            if ! oc_signal "$pid"; then status=signal_error; errors=$((errors + 1)); failed=1
            else
                for ((i=0; i<=5; i++)); do
                    current=$(oc_lookup "$pid"); rc=$?
                    if [ "$rc" -eq 3 ]; then status=confirmed_exit; confirmed=$((confirmed + 1)); break
                    elif [ "$rc" -ne 0 ]; then status=collection_error; errors=$((errors + 1)); failed=1; break
                    elif [ "$(oc_identity "$row")" != "$(oc_identity "$current")" ]; then status=identity_changed; skipped=$((skipped + 1)); failed=1; break
                    fi
                    [ "$i" -eq 5 ] || oc_pause
                done
                if [ -z "$status" ]; then status=still_running; survivors=$((survivors + 1)); failed=1; fi
            fi
        fi
        oc_result "$pid" "$status" || { failed=1; break; }
        # Stop on collection/logging failure; never proceed blindly to later PIDs.
        case "$status" in collection_error|logging_error) break ;; esac
    done
    oc_result summary "attempted=$attempted confirmed_exits=$confirmed disappeared_before_signal=$disappeared survivors=$survivors skips=$skipped errors=$errors" || failed=1
    exec 3>&-
    return "$failed"
}
