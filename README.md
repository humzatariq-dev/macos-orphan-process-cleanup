# macOS Orphan Process Cleanup

## Development roadmap

See the [adoption-ready release tracker](docs/ROADMAP.md) for the agreed
milestones, implementation tasks, acceptance criteria, dependencies, and release
gates. Milestones 1–3 are the planned scope; milestones 4–5 are optional backlog.
**These improvements are planned, not implemented: the script currently retains
the behavior described below.**

**Reclaim gigabytes of wasted RAM on your Mac — cleans up orphaned headless Chrome instances and leaked/duplicated MCP (Model Context Protocol) server processes that pile up in Activity Monitor and never exit.**

No dependencies. No `sudo`. Pure bash + the tools that ship with macOS. Logs exactly what it killed and **how much memory it freed**.

```
[2026-09-26 17:24:10] TOTAL MEMORY RECLAIMED BY THIS RUN: 77.5 MB
```

---

## Do you need this?

Open **Activity Monitor → Memory** (or run `ps -axo pid,rss,etime,comm | sort -k2 -nr | head`) and check for:

- 🔴 **`Google Chrome --headless=new --screenshot=...`** processes that are **hours or days old**, each eating 100–700 MB. These come from screenshot / DOM-dump / PDF-export automation (`--virtual-time-budget`, Puppeteer-style scripts, agent/LLM tooling) that hung instead of exiting. They get reparented to `launchd` (PID 1) and sit there forever.
- 🔴 **Dozens (even 100+) copies of `node .../some-mcp-server/index.js`** — leaked MCP server processes. Every client connection spawns one; crashed or disconnected sessions never reap them. Individually small (~6 MB), collectively **hundreds of MB to GBs**.
- 🔴 Your Mac feels sluggish, swap usage is climbing, or you're "out of memory" despite closing all your apps.

**Real-world example** (this repo exists because it actually happened):

| Leak | Count | Memory |
|---|---|---|
| Orphaned `Chrome --headless=new` (26h old) | 11 | 1.76 GB |
| Leaked `godot-mcp` node servers | 114 | 786 MB |
| **Total recovered** | | **~2.5 GB** |

Free memory went from **55% → 66%** in under a minute.

## Quick start

```bash
git clone https://github.com/humzatariq-dev/macos-orphan-process-cleanup.git
cd macos-orphan-process-cleanup
chmod +x cleanup_orphan_processes.sh

./cleanup_orphan_processes.sh --dry-run   # preview what it would kill (safe)
./cleanup_orphan_processes.sh             # clean up, keeping anything < 3h old
```

Or run it straight from the web without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/humzatariq-dev/macos-orphan-process-cleanup/main/cleanup_orphan_processes.sh | bash
```

## Usage

```
./cleanup_orphan_processes.sh [max_age_hours]        # default: 3
./cleanup_orphan_processes.sh 2                      # keep only processes < 2h old
./cleanup_orphan_processes.sh --dry-run              # preview, kill nothing
./cleanup_orphan_processes.sh -n 6                   # preview candidates 6h+
```

| Option | Meaning |
|---|---|
| `max_age_hours` | Kill matching MCP/node processes **older than** this many hours. Recent ones are kept so you don't break live connections. Default `3`. |
| `-n`, `--dry-run` | Print what would be killed and the memory it would free, without killing anything. |
| `-h`, `--help` | Show help. |

Every run appends a timestamped log to `~/cleanup_orphan_processes.log` (override with `LOGFILE=/path/to/file`).

## What it cleans (and what it never touches)

✅ **Kills:**
1. All processes matching `Chrome --headless=new` — headless automation leftovers are never user-facing work, so these are killed regardless of age.
2. Processes matching `godot-mcp/build/index.js` **older than the age cutoff** — keeps recently spawned servers alive so active editor/agent MCP sessions survive.

❌ **Never touches:**
- Your real Chrome browsing session (only `--headless=new` matches; the main browser has no such flag)
- MCP servers younger than the cutoff
- Any system process, launch agent, or anything else

### Cleaning up your own leaked processes?

The patterns are two variables at the top of the script — change them to match whatever leaks on your machine (e.g. `vite`, `playwright`, another MCP server entrypoint):

```bash
CHROME_PATTERN='Chrome --headless=new'
MCP_PATTERN='godot-mcp/build/index\.js'
```

## Automate it (optional)

Run it nightly with `launchd`, or simply add to your crontab (`crontab -e`):

```cron
0 22 * * * /path/to/macos-orphan-process-cleanup/cleanup_orphan_processes.sh 3
```

## How it works

1. **Finds candidates** with `ps`/`pgrep` against the configured command-line patterns.
2. **Filters by age** using `ps -o etime` (elapsed time). Anything with a day field (`DD-HH:MM:SS`) or hours ≥ the cutoff is considered stale. This is what keeps brand-new processes safe.
3. **Measures memory** via RSS totals before/after and `memory_pressure -Q` for the system-wide free percentage.
4. **Logs everything** to your console and a log file, including the total MB/GB reclaimed — so you can see exactly how it helped.

Why these processes exist in the first place:
- **Headless Chrome hangs**: `--virtual-time-budget` renders the page and *should* exit, but rendering/networking edge cases leave the process alive with nothing reaping it. Since its parent shell exited, it's orphaned to `launchd`.
- **MCP server leaks**: MCP clients (editor extensions, agent tooling) spawn a stdio server per connection. On crash/restart the child is orphaned and idles forever waiting on stdin that will never come.

## Sample output

```
[2026-09-26 17:22:00] ===== orphan-process-cleanup started (max age: 3h) =====
[2026-09-26 17:22:00] System free memory before: 60%
[2026-09-26 17:22:00] Headless Chrome orphans: 11 process(es), 1763.2 MB
[2026-09-26 17:22:02] Headless Chrome after: 0.0 MB -> freed 1763.2 MB
[2026-09-26 17:22:02] MCP server processes: 87 total (786.4 MB), 73 older than 3h
[2026-09-26 17:22:04] MCP servers after: 169.4 MB across 14 kept process(es) -> freed 617.0 MB
[2026-09-26 17:22:04] System free memory after: 66% (was 60%)
[2026-09-26 17:22:04] TOTAL MEMORY RECLAIMED BY THIS RUN: 2380.2 MB
[2026-09-26 17:22:04] ===== run finished =====
```

See [docs/sample-run.txt](docs/sample-run.txt) for the full story behind this repo.

## FAQ

**Is it safe to run?**
Yes. It only kills processes matching two narrowly scoped command-line patterns, and the MCP side is age-gated so recent processes survive. Use `--dry-run` first if you want to see exactly what it will do.

**Do I need `sudo`?**
No — it only touches your own user's processes.

**Will it close my Chrome tabs?**
No. Your browser runs without `--headless=new`; only headless automation instances match.

**It killed something I wanted!**
Increase the age cutoff (e.g. `./cleanup_orphan_processes.sh 12`) or adjust the patterns at the top of the script.

**Does this fix the root cause?**
No — it reclaims leaked memory. The bugs are in whatever spawned the processes (automation tooling, MCP clients). Consider updating those tools; use this as a safety net.

## License

[MIT](LICENSE) — free to use, modify, and share.

---

*Keywords: macOS memory cleanup, free up RAM Mac, Activity Monitor high memory, orphaned processes macOS, zombie processes, Chrome headless not closing, `--headless=new` stuck, MCP server processes piling up, node process leak Mac, memory_pressure, cleanup script, launchd orphan, Mac out of memory, reclaim memory macOS, process leak cleanup.*


