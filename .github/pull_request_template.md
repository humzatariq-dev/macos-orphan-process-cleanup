## Summary

Task IDs (for example M3-03):

What changed and why:

## Verification

Commands/results and actual OS/build, architecture, Bash version:

## Checklist

- [ ] Relevant tracker task IDs linked; no premature release/completion claims.
- [ ] Syntax/ShellCheck covers all `*.sh` and `orphan-cleanup`; tests pass via `/bin/bash tests/run.sh` (or limitations explained).
- [ ] Profile changes include positive and negative/ambiguous fixtures.
- [ ] Safety impacts reviewed: default scan, UID/ancestry exclusions, selection, confirmation, revalidation, logging, SIGTERM-only.
- [ ] Chrome remains report-only; Unity/automation remain deferred unless separately approved.
- [ ] README/profile/contributor/demo documentation updated as needed.
- [ ] Output/log redaction checked; no tokens, usernames, private paths, or real process listings committed.
- [ ] Tests used fixtures or guarded disposable processes, not ambient application cleanup.
- [ ] Install/uninstall/package verification recorded if relevant; planned CI is not described as passed.
