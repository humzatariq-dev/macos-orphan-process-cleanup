# Synthetic, scan-only demo

Run from the repository root on macOS with `/bin/bash`. This uses the actual
shared CLI with the test fixture runner's collection and signal seams, not your
process list. PIDs, dates, paths, and RSS are synthetic; no real memory savings
are demonstrated. The runner is test-only, not a production option.

```bash
(
  set -eu
  demo=$(mktemp -d)
  trap 'rm -rf "$demo"' EXIT
  mkdir "$demo/home"
  export HOME="$demo/home" LOGFILE="$demo/cleanup.log"
  export SIGNAL_RECORDER="$demo/signals" SCENARIO=
  : > "$SIGNAL_RECORDER"
  /bin/bash tests/cli_fixture.sh scan
  test ! -s "$SIGNAL_RECORDER"
  test ! -e "$LOGFILE"
)
```

Expected synthetic output (columns are tab-separated):

```text
PID PROFILE AGE RSS_KiB PPID STATUS REASON
100 godot-mcp 03:00:00 1024 1 review eligible
101 godot-mcp 03:00:00 1024 1 review eligible
102 headless-chrome 03:00:00 2048 1 keep ambiguous_command
Candidates: 2; estimated candidate RSS: 2048 KiB (not measured RAM freed).
No processes terminated.
```

The two Godot rows are eligible for review, not proof of inactivity. The Chrome
fixture has ambiguous flattened arguments and is kept; Chrome remains report-only
even for unambiguous matches. No command lines or synthetic secret markers appear
in default scan output. Do not add `--verbose` for screenshots or issue reports.

The assertions verify no recorded signals and no log file, with both HOME and
LOGFILE isolated in the temporary directory. This demo never invokes `clean`.
It does not verify installation, live-process behavior, or the planned CI matrix.
The broader `/bin/bash tests/run.sh` suite also covers guarded disposable-child
behavior and CLI/PTY cases (development dependency: Python 3).

## Shareable assets

- [SVG terminal preview](assets/scan-demo.svg): embedded in the README.
- [Portable terminal recording](assets/scan-demo.cast): asciicast v2, generated
  from the same actual fixture scan output. If you already have an asciicast v2
  player, open it there; a player is not a production dependency. No external
  hosting, upload, or embedded third-party player is needed for the README preview.

Regenerate both assets from the repository root with development-only Python 3:

```bash
python3 scripts/demo.py
```

The generator uses a temporary HOME/log/signal recorder, invokes only fixture
`scan`, asserts no signals/logs, and rejects fixture secret text in its output.
It renders the real fixture result rather than inventing process rows. Timing is
staged for readability; it is not a measurement of runtime performance.
