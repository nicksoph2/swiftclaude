# Claude Config Manager - Chat Prompts In Order

Use these in order.

For each numbered prompt:

1. Start a new chat.
2. Open the local files listed under **Use these local docs** in the workspace and let the AI read them directly.
3. Then paste the prompt block exactly as written.
4. You do not need to paste document contents or prior handoff summaries unless you are using a chat tool that cannot read local workspace files.

Do not ask the AI to work on more than one packet in a single chat.

Current workspace note:

- The planning docs currently live flat in `Documents/Dev/claude/devDiscoverApp/Documents/`.
- All document references below use the exact on-disk paths for this workspace.

---

## 1) Implement A1_XCODE_SETUP

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/A1_XCODE_SETUP.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet A1_XCODE_SETUP only.

Return:
1. design notes
2. proposed file and folder layout
3. full code for the initial SwiftUI macOS app shell
4. any project configuration notes needed in Xcode
5. minimal tests if relevant
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet A1 only.
- Do not start bookmark handling, root selection, discovery, parsing, resolver logic, or saving.
- Use Swift and SwiftUI.
- Keep the architecture aligned to the project index.
- The app should launch and show Managed, User, Project, and Session as stub scope screens.
- Do not introduce a database, network dependency, or third-party framework.
- Produce complete code, not partial snippets.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 2) Implement A2_APP_SANDBOX_AND_BOOKMARKS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/A2_APP_SANDBOX_AND_BOOKMARKS.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet A2_APP_SANDBOX_AND_BOOKMARKS only.

Return:
1. design notes
2. the Swift types and files to add or update
3. full code for sandbox-safe folder access and security-scoped bookmark persistence
4. app-owned storage design for bookmark metadata
5. tests or test strategy
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet A2 only.
- Do not implement Claude-specific discovery yet.
- Do not modify Claude-owned files.
- Keep bookmark code isolated from UI as much as practical.
- Support both the global Claude root folder and project root folders.
- Detect stale or invalid bookmarks and expose a reauthorization path.
- Keep all persistence in app-owned infrastructure only.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 3) Implement A3_GLOBAL_AND_PROJECT_ROOT_PICKERS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/A3_GLOBAL_AND_PROJECT_ROOT_PICKERS.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet A3_GLOBAL_AND_PROJECT_ROOT_PICKERS only.

Return:
1. design notes
2. view models and data models
3. full SwiftUI code for selecting the global Claude root and one or more project roots
4. persistence wiring to bookmark storage and global app state
5. validation messaging behavior
6. tests or test strategy
7. assumptions made
8. edge cases
9. end-of-chat handoff summary

Rules:
- Stay inside Packet A3 only.
- Do not scan folders for Claude files yet.
- Do not imply that root selection changes precedence rules.
- Prevent duplicate project registrations using normalized paths.
- The UI should clearly distinguish the default global root from an override.
- Keep Session read-only and out of scope.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 4) Implement B1_ROOT_LOCATOR

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/B1_ROOT_LOCATOR.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet B1_ROOT_LOCATOR only.

Return:
1. design notes
2. discovery-facing Swift types
3. full code for the RootLocator service and root resolution models
4. normalization rules for selected folders
5. issue reporting behavior
6. tests
7. assumptions made
8. edge cases
9. end-of-chat handoff summary

Rules:
- Stay inside Packet B1 only.
- Do not recursively scan for files yet.
- Do not parse file contents.
- The service must deterministically choose the effective global Claude root.
- The service must explain why a root was chosen and surface access issues safely.
- Project roots must be normalized consistently and returned as stable references.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 5) Draft B2_PROJECT_SCANNER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/B1_ROOT_LOCATOR.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/B2_PROJECT_SCANNER.md`.

The packet should cover recursive project scanning beneath resolved roots and discovery of Claude-related file references without parsing file contents.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/B2_PROJECT_SCANNER.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Match the style and granularity of the existing packet docs.
- Keep the scope small enough for one later implementation chat.
- Do not mix parsing or resolver logic into this packet.
- Make the packet depend on B1 where appropriate.
- Include goal, why this packet exists, inputs, dependencies, deliverables, suggested Swift types, acceptance criteria, out of scope, done when, and suggested next packet.
```

---

## 6) Draft B3_DISCOVERY_MODELS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/B1_ROOT_LOCATOR.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/B2_PROJECT_SCANNER.md` if you already drafted it

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/B3_DISCOVERY_MODELS.md`.

The packet should define the typed discovery outputs used by parsers and resolvers, including file references, scope identity, path provenance, and discovery issues.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/B3_DISCOVERY_MODELS.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Match the style and granularity of the existing packet docs.
- Keep the packet focused on shared discovery models only.
- Do not re-implement root location or scanning in this packet.
- Make sure later parser packets can consume these types cleanly.
```

---

## 7) Implement B2_PROJECT_SCANNER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/B2_PROJECT_SCANNER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet B2_PROJECT_SCANNER only.

Return:
1. design notes
2. proposed file list
3. full code for project scanning and discovery of Claude-related files
4. how the scanner classifies file types without parsing content
5. tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet B2 only.
- Use the resolved roots from B1.
- Discover Claude-related files and directories only.
- Do not parse the contents of discovered files.
- Surface inaccessible paths and partial-scan issues safely.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 8) Implement B3_DISCOVERY_MODELS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/B3_DISCOVERY_MODELS.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet B3_DISCOVERY_MODELS only.

Return:
1. design notes
2. model list
3. full code for the shared discovery domain models
4. how the models distinguish file class, scope, provenance, and issues
5. tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet B3 only.
- Keep the models stable enough for parser and resolver packets.
- Do not add parsing or resolution logic.
- The models should represent user, project, local, managed, imported, and auto-memory sources where relevant.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 9) Implement C1_SETTINGS_JSON_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet C1_SETTINGS_JSON_PARSER only.

Return:
1. design notes
2. parser-facing Swift types
3. full code for parsing Claude settings.json files into a typed domain model
4. syntax diagnostics behavior
5. fixture and test code
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet C1 only.
- Do not treat `~/.claude.json` fields as valid `settings.json` fields.
- Preserve unsupported keys in a forward-compatible raw structure if useful, but keep them distinct from modeled keys.
- Separate syntax problems from later semantic validation.
- Do not implement precedence or merging here.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 10) Draft C2_CLAUDE_JSON_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`.

The packet should cover parsing `~/.claude.json` as a distinct file family for global preferences and user or local MCP state, without confusing it with `settings.json`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Match the style and granularity of the existing packet docs.
- Make the distinction from `settings.json` explicit.
- Keep precedence and resolver rules out of this packet.
```

---

## 11) Draft C3_MCP_JSON_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`.

The packet should cover parsing `.mcp.json`, including typed server definitions, transport forms, headers, env maps, and parse-time diagnostics.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep environment expansion out of this parser packet if that belongs to resolver or validation stages.
- Keep the scope narrow enough for one implementation chat.
```

---

## 12) Draft C4_CLAUDE_MD_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`.

The packet should cover parsing Claude instruction markdown files, import tokens such as `@path/to/file`, and parse-time import token diagnostics without doing full resolution.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep full import graph resolution and load order out of this packet.
- Keep auto-memory behavior separate from user-authored instruction parsing.
```

---

## 13) Draft C5_AGENT_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md`.

The packet should cover parsing agent markdown files with YAML frontmatter and prompt body, including parse-time diagnostics for malformed frontmatter.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep duplicate-name and precedence logic out of this parser packet unless they are represented only as later semantic concerns.
- Keep the packet focused on file parsing and typed output.
```

---

## 14) Draft C6_SKILL_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md`.

The packet should cover parsing skill directories with `SKILL.md`, supported frontmatter, supporting-file references, and parse-time diagnostics.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep resolver behavior and active-skill semantics out of this parser packet.
- Keep the packet small enough for one implementation chat.
```

---

## 15) Implement C2_CLAUDE_JSON_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet C2_CLAUDE_JSON_PARSER only.

Return:
1. design notes
2. parser-facing Swift types
3. full code for parsing `~/.claude.json`
4. syntax diagnostics behavior
5. fixtures and tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet C2 only.
- Keep this file family distinct from `settings.json`.
- Parse preferences and user or local MCP-related structures only as documented by the packet.
- Do not implement precedence or resolver behavior here.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 16) Implement C3_MCP_JSON_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet C3_MCP_JSON_PARSER only.

Return:
1. design notes
2. parser-facing Swift types
3. full code for parsing `.mcp.json`
4. syntax diagnostics behavior
5. fixtures and tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet C3 only.
- Parse typed MCP server definitions and transport variants.
- Do not implement cross-scope precedence here.
- Keep parse-time diagnostics separate from later semantic validation.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 17) Implement C4_CLAUDE_MD_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet C4_CLAUDE_MD_PARSER only.

Return:
1. design notes
2. parser-facing Swift types
3. full code for parsing Claude instruction markdown files and import tokens
4. syntax diagnostics behavior
5. fixtures and tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet C4 only.
- Parse markdown content and import token references.
- Do not implement full recursive import resolution or instruction load order.
- Keep auto-memory parsing and startup semantics out of this packet unless explicitly required by the packet doc.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 18) Implement C5_AGENT_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet C5_AGENT_PARSER only.

Return:
1. design notes
2. parser-facing Swift types
3. full code for parsing agent markdown files with YAML frontmatter and prompt body
4. syntax diagnostics behavior
5. fixtures and tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet C5 only.
- Keep parser concerns separate from duplicate-name and precedence resolution.
- Frontmatter parsing should be strict enough to surface malformed content cleanly.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 19) Implement C6_SKILL_PARSER

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet C6_SKILL_PARSER only.

Return:
1. design notes
2. parser-facing Swift types
3. full code for parsing skill directories and `SKILL.md`
4. syntax diagnostics behavior
5. fixtures and tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet C6 only.
- Parse skill directory structure and `SKILL.md` frontmatter as defined by the packet.
- Do not implement skill activation or resolver behavior here.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 20) Implement D1_RESOLVER_MODELS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- any discovery and parser model code if needed

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D1_RESOLVER_MODELS only.

Return:
1. design notes
2. resolver model list
3. full code for the shared resolver domain types and SessionProjection skeleton
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D1 only.
- Do not implement precedence or merge algorithms yet.
- The model must be expressive enough for settings, instructions, MCP, agents, and skills.
- Every resolved field should be able to show effective value, winning source, participating sources, merge method, issues, and notes.
- SessionProjection must aggregate resolved snapshots without implying persistence.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 21) Draft D2_SETTINGS_PRECEDENCE

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`.

The packet should cover precedence resolution for settings sources, including managed, CLI, project local, project shared, and user settings sources.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep this packet focused on precedence selection, not deep merge behavior unless clearly separated for the next packet.
- Distinguish `settings.json` from `~/.claude.json` responsibilities.
```

---

## 22) Draft D3_SETTINGS_MERGE_RULES

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/D3_SETTINGS_MERGE_RULES.md`.

The packet should cover per-key merge behavior for settings resolution, including scalar override, deep-merge object cases, concatenation and de-duplication where documented, and permissions-related merge interpretation.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/D3_SETTINGS_MERGE_RULES.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep this packet focused on merge behavior, not on the broad precedence ladder itself.
- Keep UI concerns out of this packet.
```

---

## 23) Draft D4_INSTRUCTION_RESOLUTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md` if drafted
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`.

The packet should cover instruction load order, recursive import resolution to the allowed depth, startup-loaded instructions versus on-demand memory, and diagnostics for broken imports and cycles.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep parsing concerns out of this packet.
- Make the distinction between user-authored instructions and auto memory explicit.
```

---

## 24) Draft D5_MCP_RESOLUTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md` if drafted
- `Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md` if drafted
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`.

The packet should cover cross-scope MCP resolution, precedence across user, local, project, and managed sources, duplicate server handling, and environment expansion behavior.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep transport parsing out of this packet.
- Keep UI concerns out of this packet.
```

---

## 25) Draft D6_AGENT_SKILL_RESOLUTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md` if drafted
- `Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md` if drafted
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`.

The packet should cover project-over-user precedence, duplicate-name handling, visibility of agents and skills by scope, and diagnostics relevant to the Session view.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Keep parser concerns out of this packet.
- Keep editing behavior out of this packet.
```

---

## 26) Draft D7_SESSION_PROJECTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- any drafted D2 through D6 packet docs if available

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`.

The packet should cover assembly of the read-only Session projection from resolved settings, instructions, MCP, agents, skills, provenance, issues, and confidence notes.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- The Session view must remain computed and read-only.
- Do not introduce persistence or a shadow database.
```

---

## 27) Implement D2_SETTINGS_PRECEDENCE

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D2_SETTINGS_PRECEDENCE only.

Return:
1. design notes
2. resolver-facing Swift types or updates needed
3. full code for settings precedence resolution
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D2 only.
- Implement the source precedence ladder cleanly.
- Do not mix in per-key merge behavior unless the packet explicitly requires minimal hooks for it.
- Keep `settings.json` and `~/.claude.json` responsibilities distinct.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 28) Implement D3_SETTINGS_MERGE_RULES

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D3_SETTINGS_MERGE_RULES.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D3_SETTINGS_MERGE_RULES only.

Return:
1. design notes
2. resolver-facing Swift types or updates needed
3. full code for per-key merge behavior
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D3 only.
- Implement scalar, object, and collection merge behavior as described by the packet.
- Keep UI rendering out of scope.
- Keep precedence selection and merge behavior conceptually separate.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 29) Implement D4_INSTRUCTION_RESOLUTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D4_INSTRUCTION_RESOLUTION only.

Return:
1. design notes
2. resolver-facing Swift types or updates needed
3. full code for instruction load-order and import resolution
4. diagnostics behavior
5. tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet D4 only.
- Distinguish startup-loaded instructions from available on-demand memory.
- Support recursive import resolution only to the documented depth.
- Surface cycles, broken imports, and duplicate-content concerns cleanly.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 30) Implement D5_MCP_RESOLUTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D5_MCP_RESOLUTION only.

Return:
1. design notes
2. resolver-facing Swift types or updates needed
3. full code for MCP resolution across scopes
4. environment expansion behavior
5. tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet D5 only.
- Implement precedence and duplicate-server handling cleanly.
- Keep parsing and UI concerns out of scope.
- Surface unresolved environment-expansion issues clearly.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 31) Implement D6_AGENT_SKILL_RESOLUTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D6_AGENT_SKILL_RESOLUTION only.

Return:
1. design notes
2. resolver-facing Swift types or updates needed
3. full code for agent and skill resolution
4. diagnostics behavior
5. tests
6. assumptions made
7. edge cases
8. end-of-chat handoff summary

Rules:
- Stay inside Packet D6 only.
- Implement visibility and precedence between user and project scopes.
- Keep parser behavior and editing behavior out of scope.
- Surface duplicate-name and unsupported-shape issues clearly.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 32) Implement D7_SESSION_PROJECTION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet D7_SESSION_PROJECTION only.

Return:
1. design notes
2. projection-facing Swift types or updates needed
3. full code for building the read-only Session projection
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D7 only.
- The Session projection must be computed, not persisted.
- Do not add editing behavior.
- The projection must aggregate resolved settings, instructions, MCP, agents, skills, provenance, issues, and confidence notes.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 33) Draft SECTION_E_VALIDATION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Cover syntax, schema, and semantic validation responsibilities.
- Keep validation distinct from parsing and resolution.
- Match the style of the existing section docs.
```

---

## 34) Draft SECTION_F_SESSION_UI

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- The Session UI must be read-only.
- It should present resolved settings, instructions, hooks, MCP, agents, skills, provenance, and issues clearly.
- Keep editors out of this section.
```

---

## 35) Draft SECTION_I_FIXTURES_AND_TESTS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Cover fixture strategy, parser tests, resolver tests, and snapshot-style verification where appropriate.
- Keep this section focused on test assets and test architecture.
```

---

## 36) Draft E1_VALIDATION_MODELS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`.

The packet should define validation issue types, severity levels, codes, source references, and any shared validation result containers used across parsers and resolvers.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 37) Draft E2_SCHEMA_VALIDATION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/E2_SCHEMA_VALIDATION.md`.

The packet should cover schema-level validation for supported file families after parsing, without duplicating parse-time syntax checks.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/E2_SCHEMA_VALIDATION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 38) Draft E3_SEMANTIC_VALIDATION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/E3_SEMANTIC_VALIDATION.md`.

The packet should cover duplicate names, bad scope assumptions, unreachable imports, invalid tool syntax, unresolved env expansion, and similar semantic checks.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/E3_SEMANTIC_VALIDATION.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 39) Draft F1_SESSION_SETTINGS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/F1_SESSION_SETTINGS_VIEW.md`.

The packet should cover the read-only Session settings screen, including effective values, winning sources, merge method display, and issues.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/F1_SESSION_SETTINGS_VIEW.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 40) Draft F2_SESSION_INSTRUCTIONS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/F2_SESSION_INSTRUCTIONS_VIEW.md`.

The packet should cover the read-only Session instructions screen, including load order, imports, startup-loaded instructions, on-demand memory, and diagnostics.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/F2_SESSION_INSTRUCTIONS_VIEW.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 41) Draft F3_SESSION_HOOKS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/F3_SESSION_HOOKS_VIEW.md`.

The packet should cover the read-only Session hooks screen, including effective hooks, event grouping, matcher presentation, and hook restrictions.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/F3_SESSION_HOOKS_VIEW.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 42) Draft F4_SESSION_MCP_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/F4_SESSION_MCP_VIEW.md`.

The packet should cover the read-only Session MCP screen, including effective servers, overridden servers, source precedence, and diagnostics.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/F4_SESSION_MCP_VIEW.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 43) Draft F5_SESSION_AGENTS_SKILLS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/F5_SESSION_AGENTS_SKILLS_VIEW.md`.

The packet should cover the read-only Session agents and skills screen, including visibility by scope, precedence, duplicates, and diagnostics.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/F5_SESSION_AGENTS_SKILLS_VIEW.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 44) Draft I1_FIXTURE_LAYOUT

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`.

The packet should define the test fixture directory structure, naming strategy, representative valid and invalid cases, and how fixtures map to packet-level tests.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 45) Draft I2_RESOLVER_TESTS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/I2_RESOLVER_TESTS.md`.

The packet should cover resolver-focused unit and snapshot tests for precedence, merge behavior, import resolution, MCP resolution, and Session projection integrity.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/I2_RESOLVER_TESTS.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 46) Draft I3_PARSER_TESTS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md` if drafted

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/I3_PARSER_TESTS.md`.

The packet should cover parser-focused unit tests and fixture coverage for settings, claude.json, mcp.json, CLAUDE.md, agents, and skills.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/I3_PARSER_TESTS.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
```

---

## 47) Implement I1_FIXTURE_LAYOUT

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet I1_FIXTURE_LAYOUT only.

Return:
1. design notes
2. fixture directory plan
3. full fixture files and expected-output files where relevant
4. notes on how later packets should reuse the fixtures
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I1 only.
- Keep fixtures minimal but representative.
- Include both valid and invalid cases where relevant.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 48) Implement I2_RESOLVER_TESTS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/I2_RESOLVER_TESTS.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet I2_RESOLVER_TESTS only.

Return:
1. design notes
2. test strategy
3. full resolver test code
4. fixture usage notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I2 only.
- Cover acceptance criteria from the related resolver packets.
- Prefer deterministic tests and snapshots where the packet calls for them.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 49) Implement I3_PARSER_TESTS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/I3_PARSER_TESTS.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet I3_PARSER_TESTS only.

Return:
1. design notes
2. test strategy
3. full parser test code
4. fixture usage notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I3 only.
- Cover the parser packets already implemented.
- Keep parsing and validation expectations clearly separated.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 50) Implement E1_VALIDATION_MODELS

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet E1_VALIDATION_MODELS only.

Return:
1. design notes
2. validation model list
3. full code for shared validation issue and result types
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E1 only.
- Keep the types reusable across parsers and resolvers.
- Do not fold validation logic into the model definitions.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 51) Implement E2_SCHEMA_VALIDATION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/E2_SCHEMA_VALIDATION.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet E2_SCHEMA_VALIDATION only.

Return:
1. design notes
2. validator-facing Swift types or updates needed
3. full code for schema-level validation
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E2 only.
- Keep syntax parsing concerns out of scope.
- Keep semantic checks for a later packet unless explicitly required.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 52) Implement E3_SEMANTIC_VALIDATION

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/E3_SEMANTIC_VALIDATION.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet E3_SEMANTIC_VALIDATION only.

Return:
1. design notes
2. validator-facing Swift types or updates needed
3. full code for semantic validation
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E3 only.
- Focus on semantic issues such as duplicates, bad assumptions, unreachable imports, invalid tool syntax, and unresolved references.
- Keep UI rendering out of scope.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 53) Implement F1_SESSION_SETTINGS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/F1_SESSION_SETTINGS_VIEW.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet F1_SESSION_SETTINGS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for the read-only Session settings screen
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F1 only.
- Keep the screen read-only.
- Show effective values, winning source, merge method, issues, and notes clearly.
- Do not add editing controls.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 54) Implement F2_SESSION_INSTRUCTIONS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/F2_SESSION_INSTRUCTIONS_VIEW.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet F2_SESSION_INSTRUCTIONS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for the read-only Session instructions screen
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F2 only.
- Keep the screen read-only.
- Show load order, imports, startup-loaded instructions, on-demand memory, and diagnostics clearly.
- Do not add editing controls.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 55) Implement F3_SESSION_HOOKS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/F3_SESSION_HOOKS_VIEW.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet F3_SESSION_HOOKS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for the read-only Session hooks screen
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F3 only.
- Keep the screen read-only.
- Show effective hooks, matcher grouping, event grouping, and hook restrictions clearly.
- Do not add editing controls.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 56) Implement F4_SESSION_MCP_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/F4_SESSION_MCP_VIEW.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet F4_SESSION_MCP_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for the read-only Session MCP screen
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F4 only.
- Keep the screen read-only.
- Show effective servers, overridden servers, source precedence, and diagnostics clearly.
- Do not add editing controls.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 57) Implement F5_SESSION_AGENTS_SKILLS_VIEW

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/F5_SESSION_AGENTS_SKILLS_VIEW.md`

**Prompt**

```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: implement Packet F5_SESSION_AGENTS_SKILLS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for the read-only Session agents and skills screen
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F5 only.
- Keep the screen read-only.
- Show visibility by scope, precedence, duplicates, and diagnostics clearly.
- Do not add editing controls.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
```

---

## 58) Milestone 1 check

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- the most recent handoff summary
- a concise list of packets completed so far

**Prompt**

```text
You are helping review progress on a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: assess whether Milestone 1 is complete.

Return:
1. what Milestone 1 required
2. which packets appear complete
3. any gaps that remain before Milestone 1 can be considered done
4. a recommended cleanup or hardening list
5. the recommended first prompt for Milestone 2 planning

Rules:
- Review against the project index and packet outputs, not personal preference.
- Be concrete about what is missing.
- Do not jump into Milestone 2 implementation unless Milestone 1 is actually complete.
```

---

## 59) Draft SECTION_G_EDITORS_AND_SAVE

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_G_EDITORS_AND_SAVE.md`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_G_EDITORS_AND_SAVE.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Cover editor responsibilities, validation-before-save flow, canonical rendering, preview behavior, and atomic write-through.
- Keep Session read-only and separate from editor workflows.
- Match the style of the existing section docs.
```

---

## 60) Draft SECTION_H_USAGE

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_H_USAGE.md`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_H_USAGE.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Cover derived usage summaries, reproducible usage metadata, and any supporting fingerprint or derivation infrastructure.
- Keep billing-grade accounting and hidden databases out of scope.
- Match the style of the existing section docs.
```

---

## 61) Draft SECTION_J_RELEASE

**Use these local docs**

- `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`

**Prompt**

```text
You are helping document a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet or draft this document.

Task: draft the full markdown document for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_J_RELEASE.md`.

Return:
1. the complete markdown for `Documents/Dev/claude/devDiscoverApp/Documents/SECTION_J_RELEASE.md`
2. assumptions made
3. anything that should be added back to `Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`

Rules:
- Cover release hardening, packaging, beta readiness, regression checks, and rollout preparation.
- Keep product-scope redesign out of this section.
- Match the style of the existing section docs.
```
