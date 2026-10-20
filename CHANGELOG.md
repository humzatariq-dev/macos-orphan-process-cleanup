# Changelog

## Unreleased

No additional changes yet.

## 0.2.0 — 2026-10-19

Published as `v0.2.0` from commit `819e883`. Installation and packaging pass
locally; both hosted architecture checks and downloaded-asset verification pass. See the [release tracker](docs/ROADMAP.md)
for acceptance gates and completion evidence.

### CLI and breaking changes

- Add canonical `./orphan-cleanup` wrapper; the existing
  `./cleanup_orphan_processes.sh` shares the same core CLI.
- Default to read-only `scan`, inspecting both built-ins. `--dry-run` and `-n`
  remain scan aliases; they cannot be combined with `clean`.
- Expose deliberate `clean` with exactly one built-in profile and explicit,
  repeatable `--pid PID` selection. Preview first, then exact TTY response `yes`;
  EOF or any other response cancels. Non-TTY cleanup requires `--yes`, which
  bypasses only the prompt, never validation or safeguards.
- Add help/version reporting (`0.2.0-dev`). Keep `--verbose` scan-only.
- Reject bare numeric ages: migrate to `scan --min-age-hours N`, integer 1–8760,
  default 3. Reject unknown/duplicate options, malformed/duplicate PIDs, missing
  values, and extra positional arguments.

### Safety and outcomes

- Validate the complete selection before any signal: absent/ineligible selection
  returns 1 without signalling any PID. Revalidate the full selection after confirmation, then identity and eligibility before
  each SIGTERM; later changes can cause partial completion.
- Retain M1 elapsed-time fixes, current-user/parent/age checks, protected-PID
  exclusions, fail-closed metadata handling, and conservative command matching.
  Godot eligibility requires an unambiguous Node/script pair without extra
  arguments. All headless Chrome matches remain report-only.
- Observe termination for up to about five seconds per PID; distinguish exits,
  disappearance, skips, survivors, and errors. No SIGKILL or tree termination.
- Return 0 for success or cancellation; 1 for invalid selection or operational
  failure (including survivors); 2 for unsupported arguments/platform or root
  cleanup. Cancellation does not signal.
- Preserve `$HOME/cleanup_orphan_processes.log` with `LOGFILE` override. Require
  writable logging before signalling; omit full commands by default. Scan,
  help, and version do not write files.
- RSS remains an estimate, not measured RAM freed. Revalidation is not atomic and
  cannot eliminate PID-reuse races or guarantee that useful work is not lost.

### Documentation and development

- Update clone-and-scan onboarding, cleanup contract, migration, exit codes,
  logging, privacy, and risk guidance. Add exact built-in rules and reason codes
  in [docs/PROFILES.md](docs/PROFILES.md).
- Retain the deterministic safety harness and guarded disposable-process approach;
  tests must never clean up ambient applications. Documentation changes alone
  are not implementation or release verification evidence.
- Unity visibility remains optional and deferred, not supported. No installation
  or scheduled-cleanup workflow is offered before M3.

- Verification: 123 core assertions and 73 CLI/PTY cases pass locally, including
  confirmation-time mutation, golden scan output, and both entrypoints in a
  checkout path containing spaces. Python 3 is a development-only test dependency.

### Adoption and distribution

- Add user-local install/upgrade/uninstall with prefix support, ownership checks,
  symlink/conflict refusal, staged upgrades, and preserved logs.
- Add least-privilege macOS CI for Apple Silicon and Intel, SHA-pinned Actions,
  stock Bash checks, ShellCheck, fixture/PTY tests, installer and archive tests.
- Add committed-source packaging with a SHA-256 checksum and release checklist.
- Add synthetic scan demo, contributor instructions, redaction-aware issue forms,
  and PR checklist. Unity remains optional/deferred; Chrome remains report-only.
- CI tests now use synthetic process collection rather than ambient snapshots.
- Correct current local OS observation to macOS 27.0.1 (26A434), arm64; earlier
  macOS 26 labels were not an accurate OS-version record.

- Fix interrupted-upgrade rollback using filesystem state, with injected TERM
  regression tests at both runtime rename boundaries.
- Packaging now propagates archive failures and preserves an existing artifact
  when creation fails; covered by failure-injection tests.
