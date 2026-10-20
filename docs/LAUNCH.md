# Launch kit — drafts, not published posts

## Positioning

**Hook:** What's still running after your developer tools close?

Audience: macOS developers who use MCP, local AI agents, or browser automation
and want to investigate leftover processes. This is an audience invitation, not
support for every tool they use. Current detection covers narrow Godot MCP matches
and headless command text; Chrome is report-only. Unity and generic Node/Python,
other MCP servers, containers, and arbitrary background jobs are not supported.

The goal of this launch is feedback on read-only scans and demand for specific
profiles—not a claim of universal orphan detection, activity inference, or RAM savings.

## Short post

What's still running after your developer tools close?

I built a small macOS CLI after investigating leftover Godot MCP servers and
headless Chrome processes. It scans by default, explains matches, and doesn't
require sudo or extra runtime dependencies.

v0.2.0 is deliberately narrow: Godot MCP eligibility; Chrome report-only. It isn't
a general process cleaner. Age alone doesn't mean a process is safe to stop.

If you use MCP, local agents, or browser automation, I'd love feedback on the
read-only scan—or which specific process profile you need next. Redacted output
only; no cleanup necessary.

Repo: https://github.com/humzatariq-dev/macos-orphan-process-cleanup

## Community post

**Title: I built a scan-first macOS tool to investigate leftover developer processes**

This started with a specific frustration: investigating Godot MCP servers and
headless Chrome processes left running on my Mac. I turned the script into a
small CLI with a read-only default, explanations, tests, install/uninstall, and
an installable v0.2.0 release.

I'm interested in the broader problem for people using MCP clients, local coding
agents, and browser automation—but I don't want to pretend one name match can
reliably tell whether a process is abandoned.

What it does today:
- Scans current-user matches for two narrow built-in profiles.
- Shows age, RSS estimate, parent PID, and a reason to review or keep a match.
- Keeps Chrome report-only because flattened process listings are ambiguous.
- Allows explicit Godot PID cleanup with preview, confirmation and revalidation.
  That can still interrupt useful work; scanning is the suggested starting point.
- Uses stock macOS Bash/utilities at runtime; no sudo, daemon, or telemetry.

What it does **not** do: detect every orphan, support arbitrary Node/Python or MCP
servers, prove inactivity, promise RAM savings, or automatically clean in the
background. Unity support is deferred.

I'd particularly appreciate feedback on installation, confusing scan explanations,
and concrete missing profiles. You don't need to run cleanup or share full
commands. A tool/version description and a synthetic or carefully redacted example
are enough to start the conversation.

Repo: https://github.com/humzatariq-dev/macos-orphan-process-cleanup
Release: https://github.com/humzatariq-dev/macos-orphan-process-cleanup/releases/tag/v0.2.0

## Posting checklist

- Check the destination's current self-promotion rules before posting; these are
  adaptable drafts, not endorsements of particular communities.
- Attach `assets/scan-demo.svg` as the synthetic terminal preview where supported.
  `assets/scan-demo.cast` is a portable asciicast v2 recording. Keep the synthetic
  label visible; never present fixture output as a real leak or memory recovery.
- Link the repo and v0.2.0 release; ask for read-only feedback, not stars or kills.
- Do not post on the user's behalf without explicit authorization.
- Record recurring requested profiles before promising support. No responses or
  popularity are assumed just because these drafts exist.

## Questions that widen the net without widening termination rules

1. Which developer tool leaves processes behind, and how do you know they are no
   longer needed? A description is fine; don't upload raw command lines.
2. Would scan-only diagnostics be useful even if cleanup stays manual?
3. Was installation straightforward, and were the review/keep reasons clear?

Use the repository bug/false-positive or profile-request template. Never require
users to run cleanup, enable verbose output, or disclose private paths/tokens.
