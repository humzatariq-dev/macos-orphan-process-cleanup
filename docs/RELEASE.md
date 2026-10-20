# Release checklist

Only publish after both architecture jobs pass on the exact intended commit.
Do not equate a successful local run with verified hosted compatibility.

1. Confirm an unused version/tag; update CLI version, changelog, and package test.
2. Run `/bin/bash scripts/check.sh` using stock Bash 3.2, Python 3 and ShellCheck.
3. Push the release candidate. Wait for `macOS safety checks` on that commit:
   `macos-15` (arm64) and `macos-15-intel` (x86_64). Inspect version/build logs.
4. Record actual results in the roadmap and compatibility table, not assumptions.
5. Package committed files with `/bin/bash scripts/package.sh`. Verify the checksum
   and run `/bin/bash tests/package.sh`. The archive excludes untracked files.
6. Create tag `v0.2.0` on the verified commit; publish a GitHub release with the
   archive, `.sha256`, and migration notes. No automatic release-on-push workflow
   is enabled. Do not publish using a failing or unverified candidate.
7. Download the published asset, verify its checksum, and test version, read-only
   scan with fixture collection, and uninstall under a temporary HOME/prefix.
8. Record tag, release URL, CI run, checksum, and artifact lifecycle result.

## v0.2.0 release notes

A conservative developer utility for investigating leftover Godot MCP and
headless Chrome processes on macOS. This is not a general RAM optimizer.

**Breaking changes:** invocation now scans by default. Replace bare numeric age
arguments with `scan --min-age-hours N`. Cleanup requires explicit profile/PIDs
and exact terminal confirmation or deliberate `--yes`. Review before upgrading.

- Explainable scans, narrow Godot eligibility, revalidation and SIGTERM-only cleanup.
- Chrome remains report-only; Unity support is deferred. Neither age nor PPID 1
  proves a process is abandoned. Termination can interrupt useful work.
- User-local install/uninstall, checksum archive, fixture/PTY tests and macOS CI.
- Runtime: stock Bash 3.2 plus macOS tools. Development: Python 3 and ShellCheck.
- RSS is estimated, not measured RAM freed. Verbose command lines can expose secrets.
- Read README for installation, PATH, migration, limitations, and redacted feedback.
