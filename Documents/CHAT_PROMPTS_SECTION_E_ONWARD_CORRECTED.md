# Claude Config Manager - Corrected Prompts (Section E Onward)

Use these in order. Start a new chat for each prompt.

For each prompt:
1. Provide the **Use these local docs** list.
2. Paste the **Prompt** block exactly.

---

## 1) Implement E1_VALIDATION_MODELS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet E1_VALIDATION_MODELS only.

Return:
1. design notes
2. validation model list
3. full code for shared validation issue/result types
4. tests
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E1 only.
- Keep validation types reusable across parser/resolver/session layers.
- Do not implement schema/semantic rule logic in this packet.
- End with concise handoff summary and recommended next packet.
```

---

## 2) Implement E2_SCHEMA_VALIDATION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E2_SCHEMA_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

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
- Operate on parsed outputs only; no reparsing.
- Keep semantic/cross-file checks out of scope for this packet.
- End with concise handoff summary and recommended next packet.
```

---

## 3) Implement E3_SEMANTIC_VALIDATION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E3_SEMANTIC_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

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
- Use resolver outputs for meaning-level checks; avoid duplicating parser syntax checks.
- Keep UI rendering out of scope.
- End with concise handoff summary and recommended next packet.
```

---

## 4) Implement F1_SESSION_SETTINGS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F1_SESSION_SETTINGS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet F1_SESSION_SETTINGS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for read-only Session settings view
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F1 only.
- Projection-driven and read-only only.
- No local resolver logic in the view.
```

---

## 5) Implement F2_SESSION_INSTRUCTIONS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F2_SESSION_INSTRUCTIONS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet F2_SESSION_INSTRUCTIONS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for read-only Session instructions view
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F2 only.
- Read-only only.
- Show load order/imports/startup-memory/on-demand-memory without local resolver logic.
```

---

## 6) Implement F3_SESSION_HOOKS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F3_SESSION_HOOKS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet F3_SESSION_HOOKS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for read-only Session hooks view
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F3 only.
- Read-only only.
- Use projection-derived hooks data only.
```

---

## 7) Implement F4_SESSION_MCP_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F4_SESSION_MCP_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet F4_SESSION_MCP_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for read-only Session MCP view
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F4 only.
- Read-only only.
- Show effective/overridden servers and diagnostics from projection data.
```

---

## 8) Implement F5_SESSION_AGENTS_SKILLS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F5_SESSION_AGENTS_SKILLS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet F5_SESSION_AGENTS_SKILLS_VIEW only.

Return:
1. design notes
2. UI model updates if needed
3. full SwiftUI code for read-only Session agents/skills view
4. tests or UI test notes
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F5 only.
- Read-only only.
- Show visibility/precedence/duplicates/diagnostics from projection data.
```

---

## 9) Implement I1_FIXTURE_LAYOUT

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

Task: implement Packet I1_FIXTURE_LAYOUT only.

Return:
1. design notes
2. fixture directory plan
3. full fixture files and expected-output files where relevant
4. notes for reuse in later packets
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I1 only.
- Keep fixtures minimal but representative.
- Include valid and invalid cases where relevant.
```

---

## 10) Implement I2_RESOLVER_TESTS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I2_RESOLVER_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D3_SETTINGS_MERGE_RULES.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

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
- Cover acceptance criteria from resolver packets D2–D7.
- Prefer deterministic assertions/snapshots.
```

---

## 11) Implement I3_PARSER_TESTS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I3_PARSER_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed.

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
- Cover parser packets C1–C6.
- Keep parsing and validation expectations clearly separated.
```
