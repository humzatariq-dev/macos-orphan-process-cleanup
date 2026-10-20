# Built-in profiles (0.2.0-dev)

Only `godot-mcp` and `headless-chrome` are built in. Default scans inspect both;
`--profile` restricts reporting to one. Cleanup requires exactly one profile and
explicit PIDs; selecting a profile does not make its matches safe to terminate.
Unity visibility is optional, deferred, and unsupported.

## Shared rules and exclusions

The core collects PID, numeric UID, PPID, start time, elapsed time, RSS in KiB,
executable, and flattened command text using macOS `ps` with `LC_ALL=C`.
Only the invoking user's matches are reported; other-user commands are not shown.
Cleanup refuses root. PID 1, this tool, and its ancestor chain are excluded.

Eligibility requires valid required metadata, a round-trippable start timestamp,
valid elapsed time, elapsed age **at least** the configured threshold (default
3 hours; `--min-age-hours` accepts 1–8760), and PPID exactly 1. Elapsed forms are
`MM:SS`, `HH:MM:SS`, and `DD-HH:MM:SS`. Malformed data fails closed; collection
failure is an operational error, not permission to act on an incomplete snapshot.

## godot-mcp

Discovery matches command text containing `godot-mcp/build/index.js`. This is
intentionally broader than eligibility; discovery alone does not verify Node.
If both discovery patterns occur, Godot takes precedence.

For eligibility, all shared checks must pass, plus:

- Command text has no single quotes, double quotes, or backslash escapes.
- Splitting the flattened command on spaces gives exactly two words.
- The first word equals the separately collected executable, whose basename is
  exactly `node`.
- The second word ends in `/godot-mcp/build/index.js`.

No extra Node flags or script arguments are eligible. Unrelated Node/MCP servers,
lookalike paths, and matching text in another program do not qualify for cleanup.
Spaced/quoted paths and wrappers are ambiguous and report-only, even if legitimate.
The command is never evaluated or unescaped.

Illustrative command text (not commands to execute):

| Command text | Classification, assuming valid metadata and no exclusion |
| --- | --- |
| `/usr/local/bin/node /work/godot-mcp/build/index.js` | Eligible only if age threshold and PPID 1 also pass and executable matches. |
| `/usr/local/bin/node /work/godot-mcp/build/index.js --debug` | Discovered, report-only: `ambiguous_command`. |
| `/usr/local/bin/node /work/other-mcp/build/index.js` | Unmatched; not a generic Node cleanup target. |

## headless-chrome

Discovery matches **any command text containing `--headless`**, not a verified
Chrome executable or a reliably parsed standalone flag. This includes lookalikes
and flag-like text embedded in another argument. Ordinary Chrome without that
substring is not matched unless the Godot pattern matches.

**Every match is report-only.** Flattened `ps` text cannot prove original argument
boundaries. Even an old, current-user browser with PPID 1 cannot become eligible;
`--yes` cannot override this. No browser termination is supported.

## Scan reason codes

Checks are ordered: the first failing check determines the reason, not a complete
list of problems. Browser matches stop before age/parent eligibility checks.

| Reason | Meaning |
| --- | --- |
| `invalid_metadata` | A required numeric field, start timestamp, or elapsed value failed validation. |
| `excluded_identity` | PID 1, the tool, or an ancestor; checked after metadata. |
| `ambiguous_command` | Quotes/escapes, executable mismatch, Godot executable/argument shape failure, or any browser match. |
| `too_young` | Otherwise qualifying Godot process is below the age threshold. |
| `parent_not_pid_1` | Otherwise qualifying, old-enough Godot process has PPID other than 1. |
| `eligible` | All current Godot checks pass; not proof of inactivity or harmless termination. |

Internal `other_uid` and `unmatched` classifications are omitted from scan rows.
Normal reporting shows PID, profile, elapsed age, RSS, PPID, and reason; candidate
counts and RSS totals include only eligible records. RSS is not measured RAM freed.

## Examples and cleanup boundaries

```bash
./orphan-cleanup scan --profile godot-mcp --min-age-hours 6
./orphan-cleanup scan --profile headless-chrome
```

Use `scan --verbose` only when needed and keep its output private. To select
reviewed Godot PIDs, the syntax is:

```text
./orphan-cleanup clean --profile godot-mcp --pid PID_A --pid PID_B
```

Replace placeholders with freshly reviewed PIDs. A fresh preview precedes exact
TTY confirmation `yes`; `--yes` only bypasses that prompt. Any absent/ineligible
selection returns 1 without signalling any PID. Identity (PID, UID, start time,
and command) and eligibility are reread before each SIGTERM. Later changes can
produce skips or partial completion; no SIGKILL or tree termination follows.

## Limitations and privacy

The narrow rules prefer false negatives to guessing. PPID 1 and age do not prove
abandonment; useful work can still be interrupted. Shell checks cannot eliminate
the PID-reuse race. Full commands can contain credentials, URLs, usernames, and
private paths. Normal output and default logs omit full commands; verbose scan
output does not. Redact diagnostics before sharing and restrict access to logs.
There is no telemetry. See [README](../README.md) for log paths and exit codes.
