# Contributing

Read the [tracker](docs/ROADMAP.md), [core](lib/core.sh), and
[profile contract](docs/PROFILES.md) before changing behavior. Reference task IDs
(e.g. M3-03/M3-04); do not mark release gates complete without recorded evidence.

## Setup and checks

Use a reviewed checkout on macOS, stock `/bin/bash` 3.2, Python 3 for CLI/PTY
tests, and ShellCheck for development linting. Production has no extra runtime
dependencies. Never run tests with sudo.

```bash
/bin/bash tests/run.sh
```

`/bin/bash scripts/check.sh` syntax-checks and
ShellCheck **all `*.sh` files and `orphan-cleanup`**, then run
`/bin/bash tests/run.sh`. `/bin/bash scripts/package.sh` produces an archive and checksum
in `./dist`; inspect those artifacts and test clean install/uninstall separately.
No artifact is a published
release merely because packaging passed. Publication status is recorded in the changelog.

CI matrix: `macos-15` arm64 and `macos-15-intel` x86_64. Record actual
`sw_vers`, `uname -m`, and `/bin/bash --version` in each run; do not turn planned
coverage into claims of passing tests. Current local observation only: macOS
27.0.1, build 26A434, arm64, Bash 3.2.57.

## Safety invariants

- Default/scan/help/version never signal or create logs; verbose is scan-only.
- Current non-root UID only; exclude PID 1, self, and ancestors. Fail closed on
  missing/malformed fields or ambiguous flattened arguments.
- Godot requires the narrow executable/script match, minimum age, and PPID 1.
  Chrome stays report-only; Unity is deferred. No generic Node cleanup.
- Cleanup requires one profile, explicit unique PIDs, complete-set validation,
  fresh preview, and exact TTY confirmation or explicit `--yes`.
- Revalidate identity/eligibility immediately before each SIGTERM. Preserve
  logging-before-signalling, restrictive new-log permissions, and failure handling.
- No SIGKILL escalation, group signals, recursive tree termination, or scheduling.
  Revalidation cannot eliminate the PID-reuse race; never promise harmless cleanup.
- RSS is estimated, not measured reclaimed memory. No telemetry; omit full commands
  from default output/logs and warn about verbose secrets.

Add positive **and negative** fixtures for every profile change, including
near-misses and ambiguous commands. Preserve regressions for UID/ancestry, age,
selection atomicity, identity changes, logging failure, cancellation, CLI parsing,
and output redaction. Use fixtures or guarded disposable test-owned processes;
never clean ambient applications. The fixture runner replaces signalling; keep
that seam test-only, not a production bypass. See [demo](docs/DEMO.md).

## Reports and review

A scan is sufficient: never require cleanup to reproduce a report. Include tool
version, exact OS/build and architecture, expected/actual behavior, and minimal
redacted scan output. Remove tokens, URLs, usernames, private paths, and full
commands; inspect stderr and logs too. Use synthetic fixtures whenever possible.
Do not commit personal process listings. Explain safety impacts and update docs
and tests together; passing tests is not the same as completing release gates.
