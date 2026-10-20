# Changelog

## Unreleased

Milestone 1 is implemented and locally verified, but not a published release.
This section distinguishes implemented changes from planned scope. See the
[release tracker](docs/ROADMAP.md) for acceptance criteria and evidence.

### Breaking changes

- Change the existing script to **read-only scanning by default**. `--dry-run`
  and `-n` are scan aliases; no public `clean` command is exposed until M2.
- Reject legacy bare numeric ages. Use `--min-age-hours N` with an integer from
  1–8760 (default 3), for example
  `/bin/bash cleanup_orphan_processes.sh --min-age-hours 6`.

### Safety fixes

- Correct elapsed-time conversion and validate age thresholds conservatively.
- Add current-user, parent, age, executable, and argument checks; exclude protected
  PIDs and fail closed on malformed snapshots. Ambiguous flattened `ps` arguments,
  including spaced or quoted command paths, remain report-only.
- Add a library-tested termination primitive with explicit selection validation,
  identity and eligibility revalidation, bounded SIGTERM observation, distinct
  outcomes, and fail-closed logging. No SIGKILL escalation or tree termination.
- Treat RSS as an estimate rather than claiming exact RAM freed. Keep full command
  lines out of normal output and default logs; scans do not write logs.

### Development and documentation

- Add a deterministic safety test harness and guarded disposable-process tests,
  run with `/bin/bash tests/run.sh`, targeting stock macOS Bash 3.2.
- Rewrite onboarding around clone-and-scan examples, built-in profile filters,
  verbose-output privacy risks, PID-race limitations, and M1 versus M2/M3 scope.
- Remove remote-execution and scheduling guidance; identify the historical sample
  run as legacy. The canonical `orphan-cleanup` entrypoint is not available yet.

### Safety limitations

- All headless Chrome matches remain report-only because flattened `ps` output
  cannot prove argument boundaries. Godot eligibility requires an executable/script
  pair without additional arguments, quotes, or escapes.
- The public M1 entrypoint is read-only; the termination core is library-only
  until milestone 2 selection and confirmation are implemented.

### Planned (not implemented)

- Track optional M2-04: opt-in, report-only Unity batch-process visibility with
  explicit exclusions, redacted fixtures, and tests forbidding Unity termination.
  This task does not block milestones 2–3 or the release; default scans stay unchanged.
