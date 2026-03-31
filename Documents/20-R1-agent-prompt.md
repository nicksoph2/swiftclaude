# Implement Packet R1: Settings Resolver for Expanded Key Families

Work in this repository:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp`

Your task is to implement **Packet R1** from the planning docs. This is a coding task, not a planning-only task. Read the authoritative documents first, then inspect the current source, implement the packet end-to-end, add or update tests/fixtures as needed, run the relevant verification commands, and finish with a short handoff doc.

## Authoritative Docs To Load First

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AGENT_FRAMEWORK.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/Specs/20-R1-settings-resolver.md`
3. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/CLAUDE.md`

If wording overlaps across docs, treat the packet spec as the most specific source of truth and treat the framework plus `CLAUDE.md` as process/conventions guidance.

## Context Docs To Consult After That

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/IMPLEMENTATION_PLAN_V2.md`
3. Any existing handoff/blocker docs for this packet if present:
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/R1-handoff.md`
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/R1-BLOCKED.md`

Use those for module/dependency context, but do not let them override the packet spec.

## Packet Summary


This packet wires the expanded settings surface through the resolver so Session can display effective values with provenance and correct precedence.

## Current Source And Tests To Inspect Before Editing

- Inspect the current source files and tests closest to this packet's scope before editing.

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
otherwise keep feedback to a minimum but feed any notes into handoff
## Required Final Outputs

When finished:

1. Provide a short summary of what changed.
2. List every file created or modified.
3. State any assumptions made.
4. State any open questions, blockers, or follow-up risks.
5. Recommend the next packet.
6. Create a handoff doc at `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/R1-handoff.md`.

If you hit a real blocker requiring human input, stop and create `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/R1-BLOCKED.md`.
