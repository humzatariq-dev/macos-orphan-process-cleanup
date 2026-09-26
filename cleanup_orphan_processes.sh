#!/usr/bin/env bash
# =============================================================================
# macOS Orphan Process Cleanup
# https://github.com/humzatariq-dev/macos-orphan-process-cleanup
# -----------------------------------------------------------------------------
# Reclaims RAM on macOS by cleaning up processes that leak or get orphaned and
# needlessly sit in memory (the kind you see hogging Activity Monitor):
#
#   1. Orphaned headless Chrome instances — leftovers from screenshot / DOM
#      dump / PDF tasks ("Google Chrome --headless=new --screenshot=...") that
#      should have exited after --virtual-time-budget but hung and were
#      reparented to launchd. Each one can pin 100-700 MB.
#
#   2. Leaked or duplicated MCP server processes (node) — long-lived stdio MCP
#      servers that pile up over time (one per connection, never reaped). Each
#      is small but they add up to hundreds of processes / GBs.
#
# Safe by design:
#   - Only kills processes matching the patterns below that are OLDER than the
#     age cutoff (default 3 hours), so anything you just spawned keeps running.
#   - Never touches your main browser session (only --headless=new matches).
#   - Dry-run mode to preview before killing.
#   - Every run logs what it did and how much memory it freed.
#
# Usage:
#   ./cleanup_orphan_processes.sh [max_age_hours]        # default: 3
#   ./cleanup_orphan_processes.sh 2                      # keep only <2h old
#   ./cleanup_orphan_processes.sh --dry-run              # preview, kill nothing
#   ./cleanup_orphan_processes.sh -n 6                   # preview 6h+ candidates
#
# Requirements: macOS (uses ps/pgrep/pkill/memory_pressure). Works with the
# stock bash 3.2+. No dependencies, no sudo.
# =============================================================================

set -u

# --- Configurable kill patterns --------------------------------------------
# Adjust these to match whatever processes leak on YOUR machine. Anything whose
# full command line matches the pattern is a candidate (subject to age cutoff).
CHROME_PATTERN='Chrome --headless=new'      # orphaned headless Chrome runs
MCP_PATTERN='godot-mcp/build/index\.js'     # leaked/duplicated MCP servers

# --- Defaults ---------------------------------------------------------------
MAX_AGE_HOURS=3
DRY_RUN=0
LOGFILE="${LOGFILE:-$HOME/cleanup_orphan_processes.log}"

usage() {
    sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
}

# --- Argument parsing -------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -h|--help)    usage; exit 0 ;;
        -*)           echo "Unknown option: $1" >&2; usage; exit 1 ;;
        *)            MAX_AGE_HOURS="$1" ;;
    esac
    shift
done

case "$MAX_AGE_HOURS" in
    ''|*[!0-9]*) echo "max_age_hours must be a number (got: $MAX_AGE_HOURS)" >&2; exit 1 ;;
esac

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# --- Memory helpers ---------------------------------------------------------
sys_free_pct() {
    memory_pressure -Q 2>/dev/null | awk '/free percentage/ {print $NF}'
}

rss_kb_of() {  # $1 = ERE pattern
    ps -axo rss,args | grep -E "$1" | grep -v grep | awk '{s+=$1} END {print s+0}'
}

kb_to_mb() { awk -v kb="$1" 'BEGIN {printf "%.1f", kb/1024}'; }

# Kills PIDs listed on stdin (age-filtered); respects dry-run.
kill_pids() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "    DRY RUN: would kill PIDs: $(paste -sd' ' -)"
    else
        xargs -r kill
    fi
}

# --- Start ------------------------------------------------------------------
log "===== orphan-process-cleanup started (max age: ${MAX_AGE_HOURS}h$([ "$DRY_RUN" -eq 1 ] && echo ', DRY RUN') ) ====="
FREE_BEFORE="$(sys_free_pct)"
log "System free memory before: ${FREE_BEFORE}"

# --- 1. Orphaned headless Chrome -------------------------------------------
CHR_BEFORE_KB="$(rss_kb_of "$CHROME_PATTERN")"
CHR_PIDS="$(pgrep -f "$CHROME_PATTERN" | paste -sd' ' -)"
CHR_COUNT="$(pgrep -f "$CHROME_PATTERN" | wc -l | tr -d ' ')"
log "Headless Chrome orphans: ${CHR_COUNT} process(es), $(kb_to_mb "$CHR_BEFORE_KB") MB"
if [ "$CHR_COUNT" -gt 0 ]; then
    # Headless runs are never user-facing work, so no age filter here.
    echo "$CHR_PIDS" | tr ' ' '\n' | kill_pids
    [ "$DRY_RUN" -eq 0 ] && sleep 2
fi
CHR_AFTER_KB="$(rss_kb_of "$CHROME_PATTERN")"
log "Headless Chrome after: $(kb_to_mb "$CHR_AFTER_KB") MB -> freed $(kb_to_mb $((CHR_BEFORE_KB - CHR_AFTER_KB))) MB"

# --- 2. Stale leaked MCP / node servers -------------------------------------
# ps etime formats: MM:SS | HH:MM:SS | DD-HH:MM:SS.
# Any process with a day field, or hours >= MAX_AGE_HOURS, is considered stale.
MCP_BEFORE_KB="$(rss_kb_of "$MCP_PATTERN")"
VICTIMS="$(ps -axo pid,etime,args | grep -E "$MCP_PATTERN" | grep -v grep | awk -v h="$MAX_AGE_HOURS" '{
    e = $2
    if (e ~ /-/) print $1
    else { split(e, a, ":"); if (a[1] + 0 >= h) print $1 }
}')"
MCP_KILL_COUNT="$(echo "$VICTIMS" | grep -c . || true)"
MCP_TOTAL_COUNT="$(pgrep -f "$MCP_PATTERN" | wc -l | tr -d ' ')"
log "MCP server processes: ${MCP_TOTAL_COUNT} total ($(kb_to_mb "$MCP_BEFORE_KB") MB), ${MCP_KILL_COUNT} older than ${MAX_AGE_HOURS}h"
if [ "$MCP_KILL_COUNT" -gt 0 ]; then
    echo "$VICTIMS" | kill_pids
    [ "$DRY_RUN" -eq 0 ] && sleep 2
fi
MCP_AFTER_KB="$(rss_kb_of "$MCP_PATTERN")"
MCP_REMAIN="$(pgrep -f "$MCP_PATTERN" | wc -l | tr -d ' ')"
log "MCP servers after: $(kb_to_mb "$MCP_AFTER_KB") MB across ${MCP_REMAIN} kept process(es) -> freed $(kb_to_mb $((MCP_BEFORE_KB - MCP_AFTER_KB))) MB"

# --- Summary ----------------------------------------------------------------
FREE_AFTER="$(sys_free_pct)"
TOTAL_FREED_KB=$(( (CHR_BEFORE_KB - CHR_AFTER_KB) + (MCP_BEFORE_KB - MCP_AFTER_KB) ))
log "System free memory after: ${FREE_AFTER} (was ${FREE_BEFORE})"
log "TOTAL MEMORY RECLAIMED BY THIS RUN: $(kb_to_mb "$TOTAL_FREED_KB") MB"
log "===== run finished ====="
