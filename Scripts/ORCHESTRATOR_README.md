# Orchestrator Quick-Start Guide

## Prerequisites

1. **Claude Code CLI** installed:
   ```bash
   npm install -g @anthropic-ai/claude-code
   ```

2. **API key** set:
   ```bash
   export ANTHROPIC_API_KEY="sk-ant-your-key-here"
   ```

3. **Xcode** with Swift toolchain (you already have this)

## How It Works

The orchestrator (`Scripts/orchestrator.sh`) processes implementation packets one at a time using Claude Code's `-p` (print) mode. For each packet it:

1. Builds a prompt from `Scripts/packet-prompts/<ID>.md` (or generates a default one)
2. Runs `claude -p` with the prompt, scoped to this project directory
3. Claude reads the plan, implements the code, writes tests, and runs them
4. If tests fail, Claude gets one retry to fix them
5. If still failing, the packet is marked FAILED and you're asked whether to continue
6. If Claude hits a blocker needing human input, it writes a `<ID>-BLOCKED.md` file
7. Reports are saved to `Documents/orchestrator-reports/`

## Quick Start

```bash
cd /path/to/devDiscoverApp

# See what would run
./Scripts/orchestrator.sh --dry-run

# Run everything (skips already-completed packets)
./Scripts/orchestrator.sh

# Run just one packet
./Scripts/orchestrator.sh --packet G1

# Resume from a specific packet
./Scripts/orchestrator.sh --from H1

# Check status
./Scripts/orchestrator.sh --status

# Reset all state and start fresh
./Scripts/orchestrator.sh --reset
```

## Configuration

Set these environment variables before running:

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | (required) | Your Claude API key |
| `CLAUDE_MODEL` | `sonnet` | Model to use (`sonnet`, `opus`, `haiku`) |
| `CLAUDE_MAX_TURNS` | `25` | Max agentic turns per packet |
| `CLAUDE_MAX_BUDGET` | `5.00` | USD spending cap per packet |

**Recommended settings by phase:**

```bash
# Phases 1-4 (complex foundation work) — use opus
CLAUDE_MODEL=opus CLAUDE_MAX_TURNS=30 ./Scripts/orchestrator.sh --from G1

# Phases 5-7 (straightforward key additions) — sonnet is fine
CLAUDE_MODEL=sonnet CLAUDE_MAX_TURNS=20 ./Scripts/orchestrator.sh --from S1

# Phase 8-9 (resolver + UI wiring) — opus for reliability
CLAUDE_MODEL=opus CLAUDE_MAX_TURNS=25 ./Scripts/orchestrator.sh --from R1
```

## Custom Packet Prompts

The orchestrator checks `Scripts/packet-prompts/<ID>.md` for each packet. If found, it uses that file as the prompt. If not, it generates a generic prompt that tells Claude to read the plan and implement the packet.

**Custom prompts give better results** because they:
- Tell Claude exactly which files to read first
- Specify the implementation steps in order
- Include project-specific constraints

Two examples are provided: `G1.md` and `M1.md`. For the remaining packets, you can either:
- Write custom prompts (best results, most effort)
- Let the default prompt work (good results for straightforward packets)
- Write custom prompts only for complex packets (G1, G2, M1-M4, R1-R3)

## Monitoring a Run

While the orchestrator is running:

- **Live output** appears in your terminal (which packet, success/failure)
- **Full logs** are in `Documents/orchestrator-reports/logs/`
- **Per-packet reports** are in `Documents/orchestrator-reports/<ID>-report.md`
- **Handoff docs** (written by Claude) are in `Documents/<ID>-handoff.md`
- **Blocker files** (if Claude gets stuck) are in `Documents/<ID>-BLOCKED.md`

After a run:
```bash
# Check overall status
./Scripts/orchestrator.sh --status

# Read the summary
cat Documents/orchestrator-reports/SUMMARY-*.md

# Check a specific failure
cat Documents/orchestrator-reports/G1-report.md
```

## Handling Failures

When a packet fails, you have three options:

1. **Let Claude retry** — The orchestrator automatically gives one retry for test failures
2. **Fix manually and re-run** — Fix the issue yourself, then `./Scripts/orchestrator.sh --packet G1`
3. **Skip and continue** — When prompted, say "y" to continue to the next packet

For BLOCKED packets, read the `<ID>-BLOCKED.md` file, resolve the blocker, then re-run.

## Cost Estimate

With `sonnet` at ~$3/M input + $15/M output tokens:
- Simple packets (key additions): ~$0.50-1.00 each
- Complex packets (new subsystems): ~$2.00-5.00 each
- Estimated total for all 27 packets: **$30-60**

With `opus` (roughly 5x sonnet pricing):
- Estimated total: **$150-300**

A mixed strategy (opus for complex, sonnet for simple) is recommended: **~$60-100 total**.

## File Structure After Setup

```
devDiscoverApp/
  CLAUDE.md                              <-- Agent instructions (loaded every session)
  Documents/
    IMPLEMENTATION_PLAN_V2.md            <-- The master plan
    PROJECT_INDEX.md                     <-- Project conventions
    orchestrator-reports/                <-- Generated during runs
      .orchestrator-state.json           <-- Tracks completed/failed packets
      logs/                              <-- Raw Claude output logs
      G1-report.md                       <-- Per-packet execution reports
      SUMMARY-20260331.md                <-- Run summaries
  Scripts/
    orchestrator.sh                      <-- The orchestrator script
    packet-prompts/                      <-- Custom prompts per packet
      G1.md
      M1.md
    ORCHESTRATOR_README.md               <-- This file
```
