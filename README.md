# macOS Orphan Process Cleanup

A conservative macOS tool for investigating leftover Godot MCP servers and
headless Chrome processes—not a general RAM optimizer.

## Status and scope

**Milestone 1 is implemented and locally tested.** This is a development
checkout, not the milestone 3 release. Older revisions perform cleanup by
default; review changes before running.

- **M1:** read-only scanning through the existing script, conservative selection,
  and a library-tested termination primitive with revalidation, SIGTERM, and logging.
  The primitive is not a public cleanup interface.
- **M2:** deliberate public cleanup and the fuller CLI workflow. **No public
  `clean` command is exposed in M1.**
- **Optional M2 extension:** Unity batch-process visibility, report-only and
  opt-in; planned, not implemented. Unity termination is outside its scope.
- **M3:** CI, versioned installation, onboarding, and release verification.

There is no canonical `orphan-cleanup` entrypoint yet. Use
`cleanup_orphan_processes.sh`. The [release tracker](docs/ROADMAP.md) defines
acceptance criteria and completion evidence; its future CLI contract is not a
list of commands available today. See also the [changelog](CHANGELOG.md).

## Requirements

macOS with stock Bash 3.2 and built-in command-line tools. No additional runtime
dependencies or `sudo` are required. Do not run as root.

## Clone and scan

Review the checked-out script before executing it, especially on older revisions.
The following examples target the M1 interface:

```bash
git clone https://github.com/humzatariq-dev/macos-orphan-process-cleanup.git
cd macos-orphan-process-cleanup
/bin/bash cleanup_orphan_processes.sh --help

# Read-only scan of both built-in profiles
/bin/bash cleanup_orphan_processes.sh

# Restrict the profile and minimum age
/bin/bash cleanup_orphan_processes.sh --profile godot-mcp --min-age-hours 6
/bin/bash cleanup_orphan_processes.sh --profile headless-chrome --min-age-hours 12

# Compatibility aliases for the same read-only scan
/bin/bash cleanup_orphan_processes.sh --dry-run
/bin/bash cleanup_orphan_processes.sh -n
```

### M1 options

| Option | Meaning |
| --- | --- |
| No arguments | Read-only scan of both profiles; no signals or log files. |
| `--dry-run`, `-n` | Aliases for read-only scanning. |
| `--min-age-hours N` | Minimum elapsed age, an integer from **1–8760**, inclusive; default **3**. |
| `--profile godot-mcp\|headless-chrome` | Scan one built-in profile instead of both. |
| `--verbose` | Include full command lines; these may contain private data. |
| `--help` | Show usage. |

Legacy bare numeric ages are rejected. Replace `cleanup_orphan_processes.sh 6`
with `cleanup_orphan_processes.sh --min-age-hours 6`. A scan result is not an
instruction to terminate a process.

## Safety model

- `godot-mcp` targets a Node executable running a script ending in
  `/godot-mcp/build/index.js`, not arbitrary Node or MCP processes.
- `headless-chrome` reports command text containing `--headless` for review.
  **All browser matches are report-only**: flattened process listings cannot
  establish whether the apparent flag was a separate argument.
- Eligibility requires the invoking non-root user's UID, PPID 1, and elapsed age
  at least the configured threshold. PID 1, the tool, and its ancestors are excluded.
  Missing or malformed required fields fail closed. Matches failing safety checks
  remain report-only with a reason.
- macOS `ps` flattens arguments into text: it does not preserve reliable argument
  boundaries or original shell quoting. Spaced or quoted command paths are
  ambiguous and **report-only**, even when they appear to match. This deliberately
  misses some legitimate candidates rather than guessing. Godot eligibility
  additionally requires exactly the executable and script, with no extra arguments.

The library termination primitive validates the complete explicit selection
before signalling, then rereads identity and eligibility immediately before each
SIGTERM. It observes outcomes for up to five seconds per PID, distinguishes exits,
skips, survivors, and errors, and does not escalate to SIGKILL or terminate trees
or process groups. Required collection or logging failures prevent signalling;
logs must be writable first and omit full commands by default. These safeguards
are tested at library level; they do not expose cleanup from the M1 CLI.

## Limitations and privacy

Age, repeated commands, and PPID 1 are clues—not proof that work is abandoned.
A long-running headless browser or MCP server may still be useful. Scanning does
not fix the client or launcher that leaked a process.

Portable shell revalidation reduces but cannot eliminate the PID-reuse race
between checking a process and signalling it. It is not atomic identity checking
and cannot guarantee that termination is harmless.

RSS is a point-in-time estimate of resident memory, not measured RAM freed.
Shared pages, changing workloads, and system memory accounting prevent exact
reclamation claims.

Normal output omits full commands. `--verbose` can expose tokens, usernames,
private paths, URLs, or other secrets. Review and redact output before sharing;
do not paste raw process listings into issues. No telemetry is part of the design.

[docs/sample-run.txt](docs/sample-run.txt) is **legacy historical output**, not an
example of M1 behavior or evidence of current safety or memory-reclamation claims.

## Help shape the next milestone

Try the read-only scan and open an issue with missed matches or confusing
explanations. Include your macOS version, expected behavior, and **redacted**
output—not secrets or private paths. The deliberate cleanup workflow follows in
milestone 2; automation and broader expansion are optional, not promised.

## Development and verification

Run the safety test harness with:

```bash
/bin/bash tests/run.sh
```

The suite covers fixtures and guarded disposable-process tests; it must not
terminate ambient processes. Passing tests alone does not complete a milestone:
see the [tracker's evidence and exit gates](docs/ROADMAP.md). Locally verified on
macOS 26 / Apple Silicon with Bash 3.2.57; other combinations remain unverified
until the milestone 3 compatibility matrix and CI are established.

## License

[MIT](LICENSE).
