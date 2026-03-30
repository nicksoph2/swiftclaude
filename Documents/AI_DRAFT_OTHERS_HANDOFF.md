# AI Handoff - How to Draft the Remaining Planning Docs

## Purpose
Use this document to hand the project to another AI session so it can draft additional section docs, packet docs, or implementation notes without needing the full original product spec every time.

## What exists already
The following planning files already exist and should be treated as the current baseline:
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_A_APP_SHELL.md`
- `Docs/Sections/SECTION_B_DISCOVERY.md`
- `Docs/Sections/SECTION_C_PARSERS.md`
- `Docs/Sections/SECTION_D_RESOLVER.md`
- `Docs/Sections/SECTION_E_VALIDATION.md`
- `Docs/Sections/SECTION_F_SESSION_UI.md`
- `Docs/Sections/SECTION_I_FIXTURES_AND_TESTS.md`
- `Docs/Packets/A1_XCODE_SETUP.md`
- `Docs/Packets/A2_APP_SANDBOX_AND_BOOKMARKS.md`
- `Docs/Packets/A3_GLOBAL_AND_PROJECT_ROOT_PICKERS.md`
- `Docs/Packets/B1_ROOT_LOCATOR.md`
- `Docs/Packets/B2_PROJECT_SCANNER.md`
- `Docs/Packets/B3_DISCOVERY_MODELS.md`
- `Docs/Packets/C1_SETTINGS_JSON_PARSER.md`
- `Docs/Packets/C2_CLAUDE_JSON_PARSER.md`
- `Docs/Packets/C3_MCP_JSON_PARSER.md`
- `Docs/Packets/C4_CLAUDE_MD_PARSER.md`
- `Docs/Packets/C5_AGENT_PARSER.md`
- `Docs/Packets/C6_SKILL_PARSER.md`
- `Docs/Packets/D1_RESOLVER_MODELS.md`
- `Docs/Packets/D2_SETTINGS_PRECEDENCE.md`
- `Docs/Packets/D3_SETTINGS_MERGE_RULES.md`
- `Docs/Packets/D4_INSTRUCTION_RESOLUTION.md`
- `Docs/Packets/D5_MCP_RESOLUTION.md`
- `Docs/Packets/D6_AGENT_SKILL_RESOLUTION.md`
- `Docs/Packets/D7_SESSION_PROJECTION.md`
- `Docs/Packets/E1_VALIDATION_MODELS.md`
- `Docs/Packets/E2_SCHEMA_VALIDATION.md`
- `Docs/Packets/E3_SEMANTIC_VALIDATION.md`
- `Docs/Packets/F1_SESSION_SETTINGS_VIEW.md`
- `Docs/Packets/F2_SESSION_INSTRUCTIONS_VIEW.md`
- `Docs/Packets/F3_SESSION_HOOKS_VIEW.md`
- `Docs/Packets/F4_SESSION_MCP_VIEW.md`
- `Docs/Packets/F5_SESSION_AGENTS_SKILLS_VIEW.md`
- `Docs/Packets/I1_FIXTURE_LAYOUT.md`
- `Docs/Packets/I2_RESOLVER_TESTS.md`
- `Docs/Packets/I3_PARSER_TESTS.md`

## Ground rules for drafting future docs
- Keep `Docs/PROJECT_INDEX.md` short and stable
- Put broad subsystem context into one section doc per subsystem
- Put one implementation-sized task into one packet doc
- Do not rewrite adjacent systems unless the change is necessary
- Preserve the core product rules:
  - Claude files are authoritative
  - no shadow database
  - Session is computed and read-only
  - root selection changes discovery paths only
  - app-owned files contain reproducible metadata only

## Recommended next docs to draft
### Next section docs
- `Docs/Sections/SECTION_G_EDITORS_AND_SAVE.md`
- `Docs/Sections/SECTION_H_USAGE.md`
- `Docs/Sections/SECTION_J_RELEASE.md`

### Next packet docs
- packet docs under Sections G, H, and J after those section docs are drafted

## Packet authoring template
Copy this and fill it in for each new packet.

```md
# Packet <ID> - <Title>

## Goal
<One-sentence statement of what this packet accomplishes>

## Why this packet exists
<Why this work is needed and which later packets depend on it>

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/<SECTION_FILE>.md`
- <any prerequisite packet docs or outputs>

## Dependencies
- <packet ids>

## Deliverables
- <files, types, tests, or docs to produce>

## Required behavior
- <clear behavioral requirements>

## Suggested Swift types
- `<TypeName>`
- `<TypeName>`

## Acceptance criteria
- <observable conditions for completion>

## Out of scope
- <explicit exclusions>

## Done when
- <final definition of done>

## Suggested next packet
- `<NEXT_PACKET_ID>`
```

## Section authoring template
Copy this and fill it in for each new section.

```md
# Section <LETTER> - <Title>

## Purpose
<What subsystem this section covers>

## Section goals
- <goal>
- <goal>

## Key design rules
- <rule>
- <rule>

## Responsibilities in this section
### <Area>
- <responsibility>

## Suggested Swift types
- `<TypeName>`
- `<TypeName>`

## Interfaces with other sections
- <relationship>

## Risks
- <risk>

## Recommended implementation order
1. <step>
2. <step>

## Packets in this section
- `<PACKET_ID>`
- likely future packets:
  - `<PACKET_ID>`

## Completion condition for Section <LETTER>
<What must be true for this section to be considered complete enough>
```

## Prompt to give the next AI
Use this exact pattern in a new chat.

```md
You are helping build a native macOS app called Claude Config Manager.

Use only the context below.

## Project index
[paste Docs/PROJECT_INDEX.md]

## Section doc
[paste one Docs/Sections/... file]

## Existing packet docs if relevant
[paste one or two related packet docs]

## Task
Draft the next planning document only.
Return:
1. the full markdown document
2. assumptions made
3. anything that should be added back to PROJECT_INDEX.md

Keep the output aligned to the selected section.
Do not redesign unrelated systems.
```

## Review checklist for any newly drafted doc
- Is the scope narrow enough for one future AI session?
- Does it avoid mixing discovery, parsing, resolver, and UI concerns?
- Does it preserve the rule that Session is computed, not persisted?
- Does it avoid implying a hidden database?
- Does it distinguish `settings.json`, `~/.claude.json`, and `.mcp.json` clearly?
- Does it define acceptance criteria and out-of-scope boundaries?

## Update rule after drafting a new doc
After any new planning doc is created:
1. add it to the relevant section or packet list in `Docs/PROJECT_INDEX.md`
2. add any milestone impact if the new doc changes sequencing
3. keep the project index compact rather than copying the full new content into it
