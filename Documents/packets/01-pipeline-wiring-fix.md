# Packet 01 — Pipeline Wiring Fix

## Context

This is the single most important packet in the project. Until it is complete, **every resolution view in the app shows empty data**. The root cause is that `buildResolverInputs()` in the full `ConfigurationPipeline` implementation constructs every resolver candidate with `document: nil`, so `resolvePrecedence()` receives no data and returns zero resolved entries for all non-managed scopes. MCP candidates are additionally never appended at all. The resolver logic itself is correct — it just receives nothing to work with.

There are currently **two files** both named `ConfigurationPipeline.swift`:
- `ClaudeConfigManager/Infrastructure/ConfigurationPipeline.swift` — a ~107-line stub **that is registered in the Xcode project**
- `ClaudeConfigManager/Infrastructure/Pipeline/ConfigurationPipeline.swift` — the ~541-line full implementation **that is NOT registered in the Xcode project and is currently untracked in git**

The goal of this packet is to delete the stub, promote the full implementation, fix the nil-document wiring, and commit the result.

## Prerequisites

None. This is the first packet.

## Deliverables

### 1. Delete the stub

Remove `ClaudeConfigManager/Infrastructure/ConfigurationPipeline.swift` (the ~107-line stub). Use `XcodeRM` so the Xcode project reference is also removed, or remove manually from `project.yml` and regenerate.

### 2. Register the full implementation

Add `ClaudeConfigManager/Infrastructure/Pipeline/ConfigurationPipeline.swift` to `project.yml` under the correct group (`Infrastructure/Pipeline`). Regenerate the Xcode project with XcodeGen. Verify the file appears in the Xcode navigator.

### 3. Resolve duplicate type declarations

The stub and the full implementation both declare some of the same types. After the stub is removed, look for any remaining duplicate declarations of:
- `PipelineState`
- `ConfigFileType`
- `ParseResultRecord`

Find any surviving duplicates with a project-wide search and remove the redundant declarations (keep the versions in the full implementation).

### 4. Fix `buildResolverInputs()` — the core wiring

Open `Infrastructure/Pipeline/ConfigurationPipeline.swift` and locate `buildResolverInputs()`. For every candidate that currently passes `document: nil`, replace it with the actual parsed document from the parse step. The parsed documents are already produced by the parsers in Phase 2 of the pipeline — they just need to be threaded through.

Specifically:
- **`SettingsSourceCandidate`** — the settings parser result is already in `parseResults`; find the record matching the file path and pass its typed document
- **Agent candidates** — same pattern: find the `ParseResultRecord` for the agent file, pass its typed `AgentDocument`
- **Skill candidates** — find the skill `ParseResultRecord`, pass its `SkillDocument`
- **CLAUDE.md candidates** — find the CLAUDE.md `ParseResultRecord`, pass its `ClaudeMdDocument`
- **MCP candidates** — the `.mcpJson` case currently creates a source and discards it; add the MCP candidates to the appropriate collection so they reach the resolver

If `ParseResultRecord` does not currently carry typed document fields (only `rawContent`/`rawTextContent`), add typed optional fields for each document type. The parse step produces these typed values — they just need storing on the record.

### 5. Fix all 8 compiler warnings

Every compiler warning in the full pipeline file is a symptom of the nil-document wiring. After fixing the wiring, all warnings must be gone. If any remain, investigate and fix them — do not suppress with `#warning` or silence.

### 6. Commit the previously untracked file

The full pipeline file has been sitting untracked. Once the above work is done, stage and commit all changes including the previously untracked `Infrastructure/Pipeline/ConfigurationPipeline.swift`.

## Implementation Notes

- Read the full pipeline file carefully before making changes. The five pipeline phases are: Discovery → Parsing → Build inputs → Resolve → Project. The `buildResolverInputs()` function is Phase 3.
- The `ParseResultRecord` struct likely needs new stored properties. Add them as optionals so existing code that constructs `ParseResultRecord` without typed documents does not break.
- `SessionProjectionBuilder.build(from:)` may have a stub or gap — if it returns an empty `SessionProjection`, investigate whether it needs completing as part of this packet. If it is a separate substantial body of work, note it in the handover document and do not attempt it here.
- Look at how the Managed scope view already populates resolution data (it works today) — use that as the pattern for the non-managed scope wiring.
- Do not change the public API of `ConfigurationPipeline`. Callsites should not need updating.

## Build Command

```bash
xcodebuild build -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet
```

## Test Requirements

Run the full test suite and confirm all existing tests pass:

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Build succeeds with zero warnings
- All existing tests pass (390+ tests green)
- The Managed scope view still works as before
- At least one non-managed scope (User or Project) now shows resolved values if config files exist on the test machine
- The file is committed to git

## Handover Note

If anything did not go as described above — for example if `SessionProjectionBuilder.build(from:)` was found to be a stub and could not be completed in this session, or if duplicate type conflicts were more extensive than expected — create a file at:

`Documents/01-handoff.md`

Record:
- Which deliverables were completed
- Which were not completed and why
- Any new information discovered (e.g. additional stub methods, missing dependencies)
- Recommended starting point for the next agent picking this up

Only create this file if the work deviated from the plan. If everything completed as described, no handover document is needed.
