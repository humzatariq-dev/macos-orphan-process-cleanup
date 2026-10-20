# Adoption-ready release tracker

Status: **required milestones 1–3 complete; v0.2.0 published and verified**.

This document is the source of truth for the next release. Milestones 1–3 are
the agreed scope, in order. Milestones 4–5 are optional backlog, not promises
and not release requirements. Public entrypoints scan by default; deliberate
cleanup now requires explicit selection and confirmation (or explicit --yes).

## Goal and boundaries

Build a small, trustworthy macOS CLI for developers investigating leftover
Godot MCP servers and headless Chrome processes. Detect broadly, explain clearly,
and terminate conservatively. Do not market it as a general RAM optimizer.

- Runtime: stock macOS Bash 3.2 and built-in command-line tools; no sudo,
  daemon, telemetry, or additional runtime dependency.
- Keep the existing repository and script entrypoint. No rewrite, GUI, Linux
  port, generic Node cleanup, automatic SIGKILL, or recursive tree termination.
- Age, duplicated commands, and PPID 1 are evidence, never proof of abandonment.
  Do not claim that eligible processes are necessarily inactive or safe to stop.
- Tests and lint tools may have development-only dependencies.
- No scheduled cleanup in this release. Existing scheduling guidance must be
  removed until a separately approved automation design exists.

## Tracking rules and definition of done

All tasks start unchecked. Task IDs are stable and can be referenced in commits
or future issues. Dependencies refer to tasks below; work may run in parallel
only when dependencies are satisfied.

A task is done only when all its acceptance criteria pass, relevant tests/docs
are committed, and evidence is entered in the completion log. Evidence must
include the commit, verification command/result, and CI run or manual test record
where applicable. A milestone completes only when all its required tasks and exit gates
pass; explicitly optional tasks are non-blocking. Do not check tasks merely because a PR was opened or code was drafted.

| Milestone | Priority | Status | Exit gate |
| --- | --- | --- | --- |
| 1. Correctness and safety | Required, first | Complete (local verification) | Fixture suite and disposable-process safety tests pass |
| 2. Useful CLI | Required, after M1 | Complete (local verification) | Documented command contract passes end-to-end tests |
| 3. Adoption-ready release | Required, after M2 | Complete (release verified) | CI, clean install/uninstall, and release checklist pass |
| 4. Community-led expansion | Optional | Deferred | Separate scope approval required |
| 5. Optional automation | Optional | Deferred | Separate safety review and scope approval required |

## Locked release contracts

These decisions remove implementation ambiguity. Changes require updating this
document and its tests in the same change.

### Selection and signalling policy

1. A scan uses a snapshot with PID, numeric UID, PPID, start time, elapsed time,
   RSS in KiB, and full command. Use a stable locale (`LC_ALL=C`). Missing or
   malformed required fields make a record ineligible; never guess values.
2. Only the invoking non-root UID is eligible. Refuse cleanup when invoked as
   root, including through sudo. Exclude PID 1, the tool itself, and its ancestor
   chain. Scans may show only current-user matches; no other-user command lines.
3. Both built-in profiles require elapsed seconds >= the minimum age AND PPID 1
   for cleanup eligibility. Default minimum age is 3 hours. Matches failing
   either condition remain visible with a keep reason. This intentionally misses
   some leaks; false negatives are preferable to broad termination.
4. `godot-mcp` matches a Node executable whose script argument ends in
   `/godot-mcp/build/index.js`; `headless-chrome` matches a Chrome executable
   with a separate `--headless` or `--headless=new` argument. A matching substring
   in an unrelated executable, shell command, or argument value is insufficient.
   Ambiguous argument parsing means report-only, not eligible.
5. A scan may inspect both built-ins. Cleanup must explicitly select exactly
   one built-in profile and at least one PID from its displayed eligible set.
   Neither confirmation nor `--yes` may override eligibility checks.
6. Immediately before each signal, reread UID, start time, command, PPID, and
   age and rerun eligibility. A changed identity or eligibility means skip.
   Explain that portable shell checks reduce, but cannot eliminate, the
   check-to-signal PID-reuse race; never promise atomic identity verification.
7. Send only SIGTERM to individually selected PIDs. Observe for up to 5 seconds
   per PID, checking identity. Record confirmed exit, still running, disappeared
   before signal, identity changed, or signal error separately. Never signal a
   replacement process or escalate to SIGKILL.

### M1 conservative matching refinement

`ps` does not preserve argv boundaries. All browser matches are report-only.
Godot eligibility requires exactly two whitespace-free words (executable and
script), without quotes or escapes. A reliable argv collector is required before
enabling browser cleanup; this may remain deferred rather than weaken safety.
Scanning still reports both profiles. This restriction supersedes any implication
below that both profiles must be cleanable in M2. M1 introduced scan-only behavior;
M2 now provides the command contract and confirmation flow below.

### CLI contract

Canonical executable name: `orphan-cleanup`. The existing
`cleanup_orphan_processes.sh` remains a supported entrypoint with the same safe
behavior. Implement the core in one place, not two diverging copies.

```text
orphan-cleanup [scan] [--profile godot-mcp|headless-chrome] [--min-age-hours N] [--verbose]
orphan-cleanup clean --profile godot-mcp|headless-chrome --pid PID [--pid PID ...] [--min-age-hours N] [--yes]
orphan-cleanup --help
orphan-cleanup --version
```

- No arguments means scan. Scan without a profile inspects both built-ins.
- `--dry-run` and `-n` remain aliases for scan; combining them with `clean`
  is an argument error. Legacy bare numeric age is rejected with a migration
  example using `scan --min-age-hours N`; it must never trigger cleanup.
- N is a positive base-10 integer, 1–8760 inclusive; reject zero, negative,
  fractional, nonnumeric, duplicate, or out-of-range values. Defaults to 3.
- PIDs are positive integers > 1. Reject malformed or duplicate PIDs, unknown
  options/profiles, extra positional arguments, and missing flag values.
- Cleanup prints a fresh preview, then requires the exact response `yes` on
  a TTY unless `--yes` is supplied. EOF or any other response cancels. Non-TTY
  cleanup without `--yes` fails without signalling. `--yes` bypasses only the
  prompt, not preview, explicit PIDs, profile, or safety filters.
- Exit codes: 0 for successful scan/help/version, successful cleanup with all
  requested PIDs confirmed exited (including disappeared before signal), or
  user cancellation; 1 for collection/logging/operational failure, ineligible
  requested PIDs, changed identity, signal failure, or survivors; 2 for invalid
  invocation, unsupported platform, or root cleanup. Validate the complete
  selected set before any signal; if any requested PID is absent/ineligible,
  fail without signalling any PID. Changes during execution may yield partial
  completion; report each outcome and return 1.
- Scan/help/version do not write files. Cleanup uses the existing default
  `$HOME/cleanup_orphan_processes.log`, with `LOGFILE` override. Verify the log
  is writable before signalling; failure is fatal. Do not log full commands
  by default; warn that verbose terminal output can contain secrets.
- Human output includes PID, profile, elapsed age, RSS estimate, PPID, status,
  and a reason. Normal output omits full commands; `scan --verbose` includes
  them. Every summary states that RSS is an estimate, not measured RAM freed.

## Milestone 1 — Correctness and safety

Deliver a tested safety core before exposing a new cleanup interface.

### M1-01 — Deterministic test harness and process fixtures

- [x] Complete M1-01. Dependencies: none.

Acceptance criteria:
- Add a single documented test command that runs on stock Bash 3.2/macOS.
- Separate collection, classification, and signalling so fixtures can replace
  process data and a signal recorder can replace kill operations.
- Fixtures include both profiles, normal Chrome, unrelated Node, other UID,
  tool/ancestor PIDs, malformed fields, missing processes, and ambiguous matches.
- Fixture tests cannot signal real processes or write to the user's home log.
- A deliberately failing assertion makes the runner exit nonzero.

Verification: run the suite with an isolated temporary HOME and assert the
signal recorder is empty for every read-only scenario.

### M1-02 — Correct age conversion and threshold validation

- [x] Complete M1-02. Dependencies: M1-01.

Acceptance criteria:
- Parse `MM:SS`, `HH:MM:SS`, and `DD-HH:MM:SS` into elapsed seconds.
- Tests assert `03:00` = 180, `03:00:00` = 10800, and `1-02:03:04` = 93784.
- Test one second below, equal to, and one second above a 3-hour cutoff.
- A 26-hour process is ineligible at a 48-hour cutoff, regardless of day field.
- Invalid elapsed formats/ranges are excluded with a reason; never treated as old.
- Test every accepted/rejected minimum-age category in the CLI contract.

Verification: table-driven parser and boundary tests; no process enumeration
or signalling needed.

### M1-03 — Conservative snapshot classification

- [x] Complete M1-03. Dependencies: M1-01, M1-02.

Acceptance criteria:
- Implement selection policy steps 1–4, including both profiles' age checks.
- Classification emits stable reason identifiers for eligible, too young,
  parent not PID 1, ambiguous command, excluded identity, and invalid metadata.
- Tests cover exact executable/script matches, misleading argument substrings,
  paths containing spaces, regular Chrome, and non-Godot Node processes.
- Old processes with an active non-1 parent and recent processes with PPID 1
  are both kept. Duplicate command lines alone never grant eligibility.
- Unsupported platform/collection failure cannot fall through into cleanup.

Verification: fixture matrix asserting eligible PID sets and exclusion reasons.

### M1-04 — Revalidation and bounded graceful termination

- [x] Complete M1-04. Dependencies: M1-03.

Acceptance criteria:
- Implement selection policy steps 5–7, including root refusal and complete-set
  validation before the first signal.
- Tests simulate UID/start-time/command/PPID changes, disappearing PIDs,
  permission errors, and a process that survives the timeout.
- The recorder proves only explicitly selected eligible PIDs receive SIGTERM,
  each at most once; no process-group, recursive, or SIGKILL operations exist.
- A guarded integration test creates its own disposable child, exercises the
  termination primitive, and verifies exit. It must never select ambient machine
  processes; use a test-only seam rather than weakening production eligibility.
- The integration test traps exit/interrupt and reaps its own test children.

Verification: fixture failure-path tests plus disposable-child integration test.

### M1-05 — Honest results and fail-closed logging

- [x] Complete M1-05. Dependencies: M1-04.

Acceptance criteria:
- Report candidate count, estimated candidate RSS, per-PID outcome, confirmed
  exits, survivors, skips, and errors without conflating attempted/confirmed exits.
- Remove calculations/claims of exact memory reclaimed from runtime output.
- Tests cover empty results, changing RSS, partial failure, unavailable optional
  memory diagnostics, and unwritable log destinations.
- A required collection or log failure sends no signals; optional diagnostics
  cannot turn an otherwise successful scan into failure.
- Default logs omit full commands; dry-run/scan creates no log.

Verification: assert output, exit codes, log contents, and recorded signals for
each scenario. M1 exit gate: all M1 tests pass under Bash 3.2; no destructive
test touches processes not created by that test.

## Milestone 2 — Useful CLI

### M2-01 — Safe command parsing and migration

- [x] Complete M2-01. Dependencies: M1-05.

Acceptance criteria:
- Implement the full locked CLI contract, including defaults, aliases,
  validation, exit codes, and legacy-invocation migration errors.
- Help documents every supported option, default, and cleanup risk.
- Existing script and canonical executable share implementation and pass the
  same behavior tests, including paths containing spaces.
- Test that no-argument, help, version, scan, dry-run, malformed input, and
  legacy numeric invocations never signal any process.

Verification: CLI argument matrix covering each branch of the contract.

### M2-02 — Explainable scan and built-in profiles

- [x] Complete M2-02. Dependencies: M2-01.

Acceptance criteria:
- Show all required human-output fields and clear eligible/keep reasons for
  current-user matches. Empty results explicitly say no matches were found.
- Profile selection limits results; default scan includes both built-ins.
- Verbose mode is opt-in and documents its command-line secret exposure risk.
- Add a profile reference with exact matching/eligibility rules, exclusions,
  false-positive/false-negative limitations, and examples for each built-in.
- No custom matcher/config execution is supported in this release; explain
  that additional profiles require implementation and fixture tests.

Verification: golden output fixtures for empty, mixed, single-profile, and
verbose scans; ensure ordinary output/logs contain no fixture secret token.

### M2-03 — Deliberate interactive and noninteractive cleanup

- [x] Complete M2-03. Dependencies: M2-02.

Acceptance criteria:
- Implement explicit profile/PID selection, fresh preview, exact confirmation,
  non-TTY refusal, cancellation, and restricted `--yes` behavior.
- Test yes/no/blank/EOF responses, missing profile/PIDs, cross-profile PID,
  ineligible PID mixed with eligible PID, and state changes after preview.
- Preview and final result visibly distinguish estimates from confirmed exits.
- Noninteractive tests prove `--yes` never broadens the chosen set or skips
  revalidation. Cancellation leaves the signal recorder empty.

Verification: pseudo-terminal tests for prompting plus piped-input tests for
non-TTY cases. M2 exit gate: end-to-end scan → select → confirm → result tests
pass for both entrypoints, including every documented exit code.

### M2-04 — Unity batch visibility (optional, non-blocking)

- [ ] Complete M2-04. Dependencies: M2-02. Priority: optional; does not block
  M2-03, milestone completion, M3, or the release.

Scope: an explicitly selected `unity-batch` scan profile, not Unity cleanup.
This is a planned extension, not a currently supported CLI value. The existing
two-profile default scan and cleanup allowlist remain unchanged.

Acceptance criteria:
- Before implementation, obtain consented, redacted examples from actual macOS
  Unity processes, with executable identity and separately known launch arguments.
  Never infer reliable argv boundaries from flattened `ps` text. If examples are
  unavailable, leave this optional task deferred.
- Identify the Unity Editor executable conservatively and report apparent batch
  automation as `automation process—activity unknown`. Age, PPID 1, duplication,
  `-batchmode`, and `-quit` must not be described as proof of abandonment.
- Expose the profile only through explicit scan selection. Default scans remain
  unchanged; no generic Unity-name/substring cleanup matcher is introduced.
- Exclude interactive editors, Unity Hub, licensing components, shader/compiler
  helpers, and unrelated executables. Unity MCP servers need separate future MCP
  profiles and must not be classified as Unity Editor processes.
- Ambiguous executable identity or argument boundaries remain report-only review
  evidence, never cleanup eligibility. Do not claim apparent flags are known argv.
- Enforce non-terminability in the core and CLI: reject `clean --profile
  unity-batch` and reject Unity PIDs supplied under any cleanup profile, including
  with `--yes`. Confirmation cannot override this restriction.
- Add positive fixtures from redacted batch examples and negative fixtures for
  every excluded category, misleading substrings, spaced paths, ambiguous flags,
  other UIDs, and malformed metadata. Fixtures contain no personal data/secrets.
- Update README/profile documentation with opt-in usage, matching boundaries,
  exclusions, privacy, and inability to establish activity. Record implementation
  in the changelog only when implemented; do not advertise planned support as live.

Verification: fixture and CLI tests prove opt-in reporting, unchanged default
scans, exclusions, and an empty signal recorder for every Unity scenario and
attempted cleanup path. Tests never launch or terminate an installed Unity app.

Automatic Unity termination requires a separate safety design and explicit
approval. It is not part of this task or a release requirement.

## Milestone 3 — Adoption-ready release

### M3-01 — macOS CI and shell linting

- [x] Complete M3-01. Dependencies: M2-03.

Acceptance criteria:
- GitHub Actions runs syntax checks, the full fixture/CLI suite, guarded
  integration tests, and ShellCheck on pull requests and pushes to main.
- Explicitly test `/bin/bash` 3.2 on macOS; fail rather than silently substituting
  a newer Bash. Document exact local verification commands and dev dependencies.
- Pin third-party Actions to commit SHAs and give jobs read-only permissions
  unless a documented release job needs more.
- No production cleanup or access to user process snapshots is part of CI tests.
- Record tested macOS versions and architectures; untested combinations are
  labeled unverified, not supported by assumption.

Verification: successful CI run on the release commit, with logs establishing
Bash version and all required checks.

### M3-02 — Versioned install and uninstall

- [x] Complete M3-02. Dependencies: M2-03.

Acceptance criteria:
- Provide a repository-owned install/uninstall mechanism with a configurable
  user-writable prefix; default `$HOME/.local`. No sudo or remote pipe-to-shell.
- Installation preserves relative runtime resources and works with a prefix
  containing spaces. `orphan-cleanup --version` matches the release version.
- Refuse to overwrite an unrelated executable; document PATH setup and upgrades.
- Uninstall removes only tool-owned installed files, preserves logs by default,
  and succeeds when repeated. Installation creates no scheduler/login item.
- Test clean install, scan, upgrade, conflict refusal, and repeated uninstall
  under a temporary HOME/prefix without touching the actual user installation.
- A Homebrew tap is a follow-up convenience, not a milestone/release blocker.

Verification: automated installation lifecycle test against the release layout.

### M3-03 — Trustworthy README and onboarding

- [x] Complete M3-03. Dependencies: M2-03, M3-02.

Acceptance criteria:
- Lead with developer use cases, read-only quick start, limitations, installation,
  cleanup selection, uninstall, and troubleshooting.
- Remove remote execution and scheduled cleanup recommendations and blanket
  guarantees that old/headless/orphaned processes are inactive or safe to kill.
- Replace exact RAM-reclaimed claims with estimated RSS language. Clearly label
  retained historical samples as legacy output, not current behavior.
- Explain live-work interruption, PPID limitations, PID-reuse race, no root,
  no automatic escalation, log location, and verbose-output privacy risks.
- Every documented command is either tested or explicitly illustrative;
  destructive examples require users to substitute deliberately chosen PIDs.
- Include a short text demo or terminal recording using synthetic/disposable
  processes. No personal paths, secrets, or unconsented process command lines.

Verification: command-by-command documentation smoke test in a clean temporary
installation and a completed review of claims against actual behavior.

### M3-04 — Contributor and feedback path

- [x] Complete M3-04. Dependencies: M3-01, M3-03.

Acceptance criteria:
- Add contributing instructions with setup, tests, safety invariants, and the
  requirement that profile changes include positive and negative fixtures.
- Add bug/false-positive and profile-request issue templates asking for version,
  tested OS/architecture, expected/actual behavior, and redacted scan output.
- Templates warn against sharing full commands, tokens, usernames, or private
  paths. Reports must not require users to run cleanup or disclose secrets.
- Add a PR checklist for tests, documentation, safety changes, and task IDs.

Verification: inspect rendered templates/checklists and follow contributor
instructions from a clean checkout.

### M3-05 — Release candidate and published release

- [x] Complete M3-05. Dependencies: M3-01, M3-02, M3-03, M3-04.

Acceptance criteria:
- Complete all required M1–M3 tasks and record their evidence before tagging `v0.2.0`.
  If that tag already exists when implementation starts, select and document
  the next unused version before modifying version metadata.
- Add changelog/release notes explicitly calling out the breaking change from
  immediate cleanup to scan-by-default and migration from bare numeric ages.
- Produce a versioned source/installable archive and SHA-256 checksum; verify
  the downloaded artifact installs and reports the intended version.
- Perform read-only smoke tests on the documented macOS/architecture matrix;
  destructive smoke tests use only test-created disposable processes.
- Publish the tag and GitHub release with installation, limitations, checksum,
  migration notes, and feedback instructions. Do not claim unpublished work
  or unverified platforms are complete/supported.

M3 exit gate: green release-commit CI, verified release artifact, successful
clean install/uninstall, accurate README, and recorded smoke-test evidence.

## Optional backlog — not committed scope

### Milestone 4 — Community-led expansion

Deferred ideas: additional tested MCP profiles, report-only custom matchers,
versioned JSON output, redacted diagnostic export, and a Homebrew tap.

Entry gate: M3 shipped and concrete user reports justify a specific feature.
Each feature needs its own design, acceptance criteria, privacy review where
relevant, and positive/negative fixtures. None blocks M1–M3 or changes the
default cleanup policy implicitly. No delivery date is promised.

### Milestone 5 — Optional automation

Deferred ideas: explicit opt-in scheduled reports; only later, narrowly scoped
cleanup if independently justified. No automatic cleanup ships under this plan.

Entry gate: M3 shipped, real demand, and a separate safety review covering
noninteractive selection, concurrent runs, launchd lifecycle, logs, notifications,
disable/uninstall behavior, and failure recovery. Start report-only. Background
termination requires explicit approval and a new acceptance-tested design.

## Completion evidence log

Append one row per completed task. Keep the checkboxes above and this log in
sync; planning/documentation work alone does not complete implementation tasks.

| Task | Commit / PR | Verification command and result | CI / manual evidence |
| --- | --- | --- | --- |
| M1-01 | `0e2fa85` | `/bin/bash tests/run.sh`: 123 assertions passed; syntax and diff checks passed | Local macOS 26, arm64, Bash 3.2.57; fixtures and guarded disposable child |
| M1-02 | `0e2fa85` | `/bin/bash tests/run.sh`: 123 assertions passed; syntax and diff checks passed | Local macOS 26, arm64, Bash 3.2.57; fixtures and guarded disposable child |
| M1-03 | `0e2fa85` | `/bin/bash tests/run.sh`: 123 assertions passed; syntax and diff checks passed | Local macOS 26, arm64, Bash 3.2.57; fixtures and guarded disposable child |
| M1-04 | `0e2fa85` | `/bin/bash tests/run.sh`: 123 assertions passed; syntax and diff checks passed | Local macOS 26, arm64, Bash 3.2.57; fixtures and guarded disposable child |
| M1-05 | `0e2fa85` | `/bin/bash tests/run.sh`: 123 assertions passed; syntax and diff checks passed | Local macOS 26, arm64, Bash 3.2.57; fixtures and guarded disposable child |
### Milestone 2 completion evidence

- M2-01: implementation commit `4d37eeb`; `/bin/bash tests/run.sh` passed
  123 core assertions and 73 CLI/PTY cases on macOS 26 arm64, Bash 3.2.57.
- M2-02: implementation commit `4d37eeb`; `/bin/bash tests/run.sh` passed
  123 core assertions and 73 CLI/PTY cases on macOS 26 arm64, Bash 3.2.57.
- M2-03: implementation commit `4d37eeb`; `/bin/bash tests/run.sh` passed
  123 core assertions and 73 CLI/PTY cases on macOS 26 arm64, Bash 3.2.57.
- Verified golden empty/mixed/profile/verbose output, secret omission, parser
  rejection paths, actual PTY consent/cancellation/EOF, piped-input refusal,
  confirmation-time second-PID mutation, full-selection preflight, and explicit
  --yes behavior. Both real entrypoints exercised with synthetic collection in a
  checkout path containing spaces; no ambient cleanup.
- Syntax checks passed for every shell file; `git diff --check` passed.
- M2-04 stays unchecked/deferred pending consented real Unity launch examples.
- M3 CI, compatibility coverage, installation and release verification remain open.

### Milestone 3 pre-publication evidence

- M3-01: `1530aac`, `3c9d2fd`, `d35a3c9`; hosted CI run `39354385806`
  succeeded for both macos-15 and macos-15-intel. The final tag target must also
  have green CI before publication; exact environment output is in job logs.
- M3-02: isolated install, upgrade, conflicts, symlinks, interrupted-rename
  rollback, log preservation and repeated uninstall passed; paths include spaces.
- M3-03: README install/scan/help/version/uninstall smoke paths covered by
  installer and package tests; synthetic text demo matches fixture golden output.
- M3-04: CONTRIBUTING.md, redaction-aware issue forms and PR checklist reviewed.
- Local full check: stock Bash 3.2.57, Python 3, ShellCheck 0.11.0; 123 core
  assertions, 73 CLI/PTY cases, install lifecycle, archive checksum/extraction,
  artifact install/version/help/uninstall, failed-package preservation passed.
- Current measured local OS: macOS 27.0.1 (26A434), arm64. Earlier evidence labels
  saying macOS 26 were inaccurate; this records the actual sw_vers observation.
- M3-05 remains open until the final commit passes CI and published assets are
  downloaded, checksum-verified and lifecycle-tested. No completion is assumed.

### Published release evidence — M3-05

- Release commit/tag: `819e8834a7eb28d80acd5bd9b6045c84e9ddad31`, `v0.2.0`.
- CI run `39354678128`: both macos-15 and macos-15-intel jobs passed on the
  exact tag target. Local full checks and committed archive lifecycle passed.
- Published release: https://github.com/humzatariq-dev/macos-orphan-process-cleanup/releases/tag/v0.2.0
- Published assets: `orphan-cleanup-0.2.0.tar.gz` and matching `.sha256`.
- SHA-256: `4d3c3dd8247689e8c6894b329b02ba89b97b4bda74210af60b3405fd9e78c531`.
- Downloaded both public assets, independently verified SHA-256, extracted and
  reran `tests/install.sh`: clean install/version, synthetic scan, upgrade,
  conflicts/symlinks, interrupted rollback, log retention and repeated uninstall
  all passed. No ambient application cleanup occurred.
- This subsequent documentation-only update records publication; the tag remains
  on its verified commit. M2-04 Unity and optional milestones 4–5 stay deferred.
