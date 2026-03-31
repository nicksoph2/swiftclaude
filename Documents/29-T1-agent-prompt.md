# Implement Packet T1: Runtime Session Snapshot

Work in this repository:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp`

Your task is to implement **Packet T1** from the planning docs. This is a coding task, not a planning-only task. Read the authoritative documents first, then inspect the current source, implement the packet end-to-end, add or update tests/fixtures as needed, run the relevant verification commands, and finish with a short handoff doc.

## Authoritative Docs To Load First

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AGENT_FRAMEWORK.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/Specs/29-T1-runtime-session-snapshot.md`
3. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/CLAUDE.md`

If wording overlaps across docs, treat the packet spec as the most specific source of truth and treat the framework plus `CLAUDE.md` as process/conventions guidance.

## Context Docs To Consult After That

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/IMPLEMENTATION_PLAN_V2.md`
3. Any existing handoff/blocker docs for this packet if present:
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T1-handoff.md`
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T1-BLOCKED.md`

Use those for module/dependency context, but do not let them override the packet spec.

## Packet Summary


This packet adds the ability to model and display live session state from running Claude Code instances. The session snapshot model mirrors the JSON payload that Claude Code pipes to the user's `statusLine` command via stdin. This provides a real-time window into active sessions including session ID, transcript path, model in use, context window usage, cost, and rate-limit state.

**Important architectural note:** Claude Code does NOT write snapshot files to disk (there is no `current.json` or `status.json`). The status-line JSON is delivered via stdin to a user-configured shell command. This packet therefore focuses on:

1. Defining Swift models that faithfully represent the documented status-line JSON schema
2. Providing a best-effort transcript-based discovery mechanism to extract session metadata from on-disk transcript files (complementing T2)
3. Laying groundwork for future integration if Claude Code adds a file-based or IPC-based session state API

This packet introduces the foundational models for the entire runtime observability track (T1–T4). It does not require parser/resolver completion and can begin once app shell and discovery foundations are stable.

## Current Source And Tests To Inspect Before Editing

Start with the files listed in the packet spec's `Pre-read files` section:


- `ClaudeConfigManager/App/AppRouter.swift` — app navigation structure
- `ClaudeConfigManager/Core/Models/` — existing model patterns
- `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift` — file discovery pattern
- `ClaudeConfigManager/Infrastructure/Discovery/RootLocator.swift` — root discovery pattern
- Claude Code status-line docs: https://code.claude.com/docs/en/statusline

Also inspect the most directly related implementation and test files under:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManager/`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/`

If the exact source files differ from the planning docs, adapt to the real codebase and note the difference in the handoff doc.

## Packet Requirements

Implement this packet exactly as described in its spec file. Treat the following sections in the packet spec as required work:

- `Overview`
- `Deliverables`
- `Acceptance criteria`

If the spec includes packet-specific models, services, fixtures, tests, or UI requirements, implement them within the scope of this packet.

## General Project Rules To Respect

- Claude-owned files are authoritative.
- Do not introduce a shadow config store.
- Preserve existing public API behavior unless the packet explicitly requires a change.
- Keep the packet scoped; do not implement later packets except for minimal compatibility shims required by this one.
- Preserve unknown fields for forward compatibility where the parser architecture expects that.
- Use `JSONValue` for flexible/untyped parser data rather than `Any` when working in parser code.
- Do not manually edit the Xcode project structure.
- Add or update tests and fixtures for the behavior you introduce.
- Do not finish with analysis only; implement, verify, and leave the packet in a handoff-ready state.

## Required Verification

Run the relevant verification commands after implementation. At minimum, if the packet changes app code or tests, run:

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet
```

If a packet is documentation-only or cannot run the full suite for a concrete reason, explain that clearly in the final report and handoff.

## Required Final Outputs

When finished:

1. Provide a short summary of what changed.
2. List every file created or modified.
3. State any assumptions made.
4. State any open questions, blockers, or follow-up risks.
5. Recommend the next packet.
6. Create a handoff doc at `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T1-handoff.md`.

If you hit a real blocker requiring human input, stop and create `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T1-BLOCKED.md`.
