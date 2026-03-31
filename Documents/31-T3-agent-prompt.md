# Implement Packet T3: Telemetry / OpenTelemetry Configuration Display (Optional)

Work in this repository:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp`

Your task is to implement **Packet T3** from the planning docs. This is a coding task, not a planning-only task. Read the authoritative documents first, then inspect the current source, implement the packet end-to-end, add or update tests/fixtures as needed, run the relevant verification commands, and finish with a short handoff doc.

## Authoritative Docs To Load First

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AGENT_FRAMEWORK.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/Specs/31-T3-otel-ingest.md`
3. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/CLAUDE.md`

If wording overlaps across docs, treat the packet spec as the most specific source of truth and treat the framework plus `CLAUDE.md` as process/conventions guidance.

## Context Docs To Consult After That

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/IMPLEMENTATION_PLAN_V2.md`
3. Any existing handoff/blocker docs for this packet if present:
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T3-handoff.md`
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T3-BLOCKED.md`

Use those for module/dependency context, but do not let them override the packet spec.

## Packet Summary


This packet adds optional support for detecting and displaying the OpenTelemetry (OTel) configuration that Claude Code uses for telemetry export. This packet is explicitly optional and should not interfere with normal operation if OTel is not configured.

**Important architectural correction:** Claude Code's OTel integration is a **push-only** model — it exports metrics and events to external collectors via standard OTLP protocol. The app **cannot query an OTel collector** for data. There is no standard read API from an OTel collector that the app could use to retrieve spans or metrics.

This packet therefore focuses on:
1. **Detecting** whether OTel is configured (from settings and environment variables)
2. **Displaying** the OTel configuration state to the user (what's being exported, where, and how)
3. **Explaining** privacy and correlation implications (for example whether prompt contents or tool details may be exported)
4. **Documenting** what metrics, events, and correlation attributes Claude Code emits (informational reference)

OTel is therefore a **supplementary observability surface** in this app. Session state, prompt history, token totals, and cost views should continue to come from status-line data and transcripts first; OTel is used to explain telemetry configuration and what Claude Code would emit if telemetry is enabled.

This packet does NOT:
- Make HTTP requests to OTel collector endpoints
- Ingest or display OTel spans, metrics, or events
- Query any external telemetry backend

## Current Source And Tests To Inspect Before Editing

Start with the files listed in the packet spec's `Pre-read files` section:


- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift` — for env/otelHeadersHelper detection
- Claude Code monitoring docs: https://code.claude.com/docs/en/monitoring-usage

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
6. Create a handoff doc at `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T3-handoff.md`.

If you hit a real blocker requiring human input, stop and create `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/T3-BLOCKED.md`.
