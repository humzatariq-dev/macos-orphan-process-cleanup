# macOS Orphan Process Cleanup

A conservative macOS tool for investigating leftover Godot MCP servers and
headless Chrome processes—not a general RAM optimizer.

## Status and scope

**M2 CLI: 0.2.0-dev**, a development checkout, not a published release.
The canonical `./orphan-cleanup` wrapper and existing
`./cleanup_orphan_processes.sh` entrypoint share one core CLI and the same safety
rules. M3 installation, CI, release verification, and distribution remain planned;
use the checkout, not installation or scheduling instructions. Optional Unity
visibility is deferred and is not supported.

See [profile rules](docs/PROFILES.md) and the [changelog](CHANGELOG.md).
The [release tracker](docs/ROADMAP.md) records acceptance gates; its milestone
status and completion evidence are maintained alongside implementation.

## Requirements and onboarding

Use macOS with stock Bash 3.2 and built-in command-line tools. No extra runtime
or sudo is needed. Never run cleanup as root. Review the checkout before running:
older revisions performed cleanup by default.

```bash
git clone https://github.com/humzatariq-dev/macos-orphan-process-cleanup.git
cd macos-orphan-process-cleanup
./orphan-cleanup --help
./orphan-cleanup --version

# Read-only: no signals or log files
./orphan-cleanup
./orphan-cleanup scan --profile godot-mcp --min-age-hours 6
./orphan-cleanup scan --profile headless-chrome
```

## CLI

```text
./orphan-cleanup [scan] [--profile godot-mcp|headless-chrome] [--min-age-hours N] [--verbose]
./orphan-cleanup clean --profile godot-mcp|headless-chrome --pid PID [--pid PID ...] [--min-age-hours N] [--yes]
./orphan-cleanup --help
./orphan-cleanup --version
```

- No arguments means read-only scan of both built-ins. `--dry-run` and `-n`
  are scan aliases, not valid with `clean`.
- Minimum age defaults to **3 hours**; N must be an integer **1–8760** inclusive.
- `clean` requires exactly one built-in profile and explicit repeated `--pid PID`
  flags. PIDs must be integers greater than 1, without duplicates. No implicit
  “all candidates” selection exists. Chrome is report-only even with `clean`.
- Unknown arguments/profiles, missing values, duplicate options (except distinct
  `--pid` selections), and extra positional arguments are rejected.
- `--verbose` is **scan-only**. It reveals full commands, potentially including
  tokens, private paths, URLs, and other secrets; redact before sharing.

### Deliberate cleanup

First scan, investigate whether work is still needed, then select actual PIDs.
The following is syntax only: replace placeholders after review, do not copy
unexamined PIDs from examples or old output.

```text
./orphan-cleanup clean --profile godot-mcp --pid PID_A --pid PID_B --min-age-hours 6
```

Cleanup collects a fresh preview and requires exactly `yes` from a TTY. Any other
response or EOF cancels successfully without signalling. Non-TTY cleanup requires
`--yes`; this skips **only the prompt**, not preview, explicit selection,
revalidation, eligibility, or logging. It is not an automation safety guarantee.

The whole selection is validated before any signal. Any absent or ineligible
selected PID fails the request without signalling any PID. Immediately before
each SIGTERM, identity and eligibility are checked again. Changes during execution
can cause partial completion. Outcomes distinguish confirmed exits, disappearance
before signal, changed identity/eligibility, survivors, and operational errors.
Observation is bounded to about five seconds per PID; there is no SIGKILL
escalation, process-group signalling, or recursive tree termination.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Successful scan/help/version; cleanup with all selected PIDs confirmed exited or disappeared before signal; user cancellation. |
| 1 | Absent/ineligible selection (no signals); collection, logging, or other operational failure; changed identity/eligibility, signal failure, or survivors. |
| 2 | Invalid/unsupported arguments, unsupported platform, or root cleanup. |

### Logs and migration

Scan/help/version do not write files. Cleanup appends to
`$HOME/cleanup_orphan_processes.log`; set `LOGFILE` to override this path.
The log must be writable before signalling; logging failures stop further work.
New logs use restrictive permissions; full commands are omitted by default.
Logs still contain process IDs and outcomes: review access and redact before sharing.

Legacy bare numeric ages are rejected. Replace
`./cleanup_orphan_processes.sh 6` with
`./orphan-cleanup scan --min-age-hours 6`. The existing script accepts the same
CLI as the wrapper. Scan output is not authorization to terminate a process.

## Safety, limitations, and privacy

Only narrowly matching Godot processes can be eligible; all Chrome matches are
report-only. See [exact rules and reason codes](docs/PROFILES.md).
Age, repeated commands, and PPID 1 are clues, not proof of abandonment. Termination
can interrupt useful work or lose data. Scanning does not fix the leaking launcher.

Flattened macOS `ps` output does not preserve argument boundaries or quoting;
ambiguous matches fail closed. Portable shell revalidation reduces but cannot
eliminate the PID-reuse race between checking and signalling. It is not atomic
identity checking and cannot guarantee harmless termination.

RSS is a point-in-time estimate, not measured RAM freed. Shared pages and changing
workloads prevent exact reclamation claims. There is no telemetry. Do not paste
raw process listings into issues. [Historical sample output](docs/sample-run.txt)
is legacy, not evidence of current behavior or memory reclamation.

## Development and verification

```bash
/bin/bash tests/run.sh
```

Tests must use fixtures or guarded disposable processes, never cleanup of ambient
applications. Passing tests alone does not satisfy release gates. M1 was locally
verified on macOS 26 / Apple Silicon with Bash 3.2.57; this is not a claim of M2
verification or an M3 compatibility matrix. Report missed matches or confusing
reasons with macOS version and redacted output.

## License

[MIT](LICENSE).

Development test dependency: Python 3 is required for the CLI and pseudo-terminal
suite; the production tool still uses only stock Bash and macOS utilities.
