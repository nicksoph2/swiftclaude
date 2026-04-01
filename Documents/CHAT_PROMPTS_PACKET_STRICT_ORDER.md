# Claude Config Manager - Strict Packet Prompts

## How To Use

Use these in order.

For each prompt:
1. Start a new chat.
2. Open the local files listed under **Use these local docs** in the workspace and let the AI read them directly.
3. Paste the prompt block exactly as written.
4. Do not combine multiple packets in one chat.

## Global Rules

Rule applied to every packet prompt:
1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
2. matching section doc for the packet letter
3. the packet doc itself

After an implementation prompt is completed and tests pass, the AI MUST create a short handoff document named after the section just completed with the affix `-handoff` (example: `SECTION_B_DISCOVERY-handoff.md`).

Implementation execution rule:
- For prompts whose Task says `implement`, the AI must directly edit code, run tests, and report results in the same chat.
- The AI must not stop at design notes, analysis, or status reports for implementation prompts unless explicitly asked.
- Do not require a follow-up "now implement" command.

Communication rule for Codex chat output:
- Do not paste full Swift/code listings in chat by default.
- Summarize what changed and reference edited file paths instead.
- Show code only when explicitly requested.

---
## Section A
---

## A1_XCODE_SETUP

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/A1_XCODE_SETUP.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet A1_XCODE_SETUP only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet A1_XCODE_SETUP only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## A2_APP_SANDBOX_AND_BOOKMARKS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/A2_APP_SANDBOX_AND_BOOKMARKS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet A2_APP_SANDBOX_AND_BOOKMARKS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet A2_APP_SANDBOX_AND_BOOKMARKS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## A3_GLOBAL_AND_PROJECT_ROOT_PICKERS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_A_APP_SHELL.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/A3_GLOBAL_AND_PROJECT_ROOT_PICKERS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet A3_GLOBAL_AND_PROJECT_ROOT_PICKERS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet A3_GLOBAL_AND_PROJECT_ROOT_PICKERS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

---
## Section B
---

## B1_ROOT_LOCATOR

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/B1_ROOT_LOCATOR.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet B1_ROOT_LOCATOR only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet B1_ROOT_LOCATOR only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## B2_PROJECT_SCANNER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/B2_PROJECT_SCANNER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet B2_PROJECT_SCANNER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet B2_PROJECT_SCANNER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## B3_DISCOVERY_MODELS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/B3_DISCOVERY_MODELS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet B3_DISCOVERY_MODELS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet B3_DISCOVERY_MODELS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

---
## Section C
---

## C1_SETTINGS_JSON_PARSER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet C1_SETTINGS_JSON_PARSER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet C1_SETTINGS_JSON_PARSER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## C2_CLAUDE_JSON_PARSER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet C2_CLAUDE_JSON_PARSER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet C2_CLAUDE_JSON_PARSER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## C3_MCP_JSON_PARSER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet C3_MCP_JSON_PARSER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet C3_MCP_JSON_PARSER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## C4_CLAUDE_MD_PARSER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet C4_CLAUDE_MD_PARSER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet C4_CLAUDE_MD_PARSER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## C5_AGENT_PARSER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C5_AGENT_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet C5_AGENT_PARSER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet C5_AGENT_PARSER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## C6_SKILL_PARSER

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C6_SKILL_PARSER.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet C6_SKILL_PARSER only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet C6_SKILL_PARSER only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

---
## Section D
---

## D1_RESOLVER_MODELS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D1_RESOLVER_MODELS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D1_RESOLVER_MODELS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## D2_SETTINGS_PRECEDENCE

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D2_SETTINGS_PRECEDENCE only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D2_SETTINGS_PRECEDENCE only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## D3_SETTINGS_MERGE_RULES

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D3_SETTINGS_MERGE_RULES.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D3_SETTINGS_MERGE_RULES only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D3_SETTINGS_MERGE_RULES only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## D4_INSTRUCTION_RESOLUTION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D4_INSTRUCTION_RESOLUTION only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D4_INSTRUCTION_RESOLUTION only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## D5_MCP_RESOLUTION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D5_MCP_RESOLUTION only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D5_MCP_RESOLUTION only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## D6_AGENT_SKILL_RESOLUTION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D6_AGENT_SKILL_RESOLUTION only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D6_AGENT_SKILL_RESOLUTION only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## D7_SESSION_PROJECTION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet D7_SESSION_PROJECTION only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet D7_SESSION_PROJECTION only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

---
## Section E
---

## E1_VALIDATION_MODELS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet E1_VALIDATION_MODELS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E1_VALIDATION_MODELS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## E2_SCHEMA_VALIDATION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E2_SCHEMA_VALIDATION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet E2_SCHEMA_VALIDATION only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E2_SCHEMA_VALIDATION only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## E3_SEMANTIC_VALIDATION

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E3_SEMANTIC_VALIDATION.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet E3_SEMANTIC_VALIDATION only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet E3_SEMANTIC_VALIDATION only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

---
## Section F
---

## F1_SESSION_SETTINGS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F1_SESSION_SETTINGS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet F1_SESSION_SETTINGS_VIEW only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F1_SESSION_SETTINGS_VIEW only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## F2_SESSION_INSTRUCTIONS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F2_SESSION_INSTRUCTIONS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet F2_SESSION_INSTRUCTIONS_VIEW only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F2_SESSION_INSTRUCTIONS_VIEW only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## F3_SESSION_HOOKS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F3_SESSION_HOOKS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet F3_SESSION_HOOKS_VIEW only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F3_SESSION_HOOKS_VIEW only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## F4_SESSION_MCP_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F4_SESSION_MCP_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet F4_SESSION_MCP_VIEW only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F4_SESSION_MCP_VIEW only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## F5_SESSION_AGENTS_SKILLS_VIEW

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/F5_SESSION_AGENTS_SKILLS_VIEW.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet F5_SESSION_AGENTS_SKILLS_VIEW only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet F5_SESSION_AGENTS_SKILLS_VIEW only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

---
## Section I
---

## I1_FIXTURE_LAYOUT

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet I1_FIXTURE_LAYOUT only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I1_FIXTURE_LAYOUT only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## I2_RESOLVER_TESTS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I2_RESOLVER_TESTS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet I2_RESOLVER_TESTS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I2_RESOLVER_TESTS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```

## I3_PARSER_TESTS

**Use these local docs**
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I3_PARSER_TESTS.md`

**Prompt**
```text
You are helping build a native macOS app called Claude Config Manager.

Use only the local documents listed above for planning context. You may inspect the current workspace code as needed to implement this packet.

Task: implement Packet I3_PARSER_TESTS only.

Return:
- Implement the system in the app, complete and integrate the code, then run fixtures and tests, amending code until the app builds, runs, and passes all tests.
1. design notes
2. files changed
3. implementation summary
4. tests run and results
5. assumptions made
6. edge cases
7. end-of-chat handoff summary

Rules:
- Stay inside Packet I3_PARSER_TESTS only.
- For this implementation prompt, directly edit code and run tests in this same chat.
- Do not stop at planning/status unless explicitly asked for planning-only output.
- Keep output concise: summarize changes and reference edited paths; only paste full code when explicitly requested.
- End with a concise handoff summary with: files created or updated, what is complete, what remains, assumptions made, open questions, and recommended next packet.
Handoff rule: if tests pass, create a short handoff document named after the section completed with the affix -handoff (example: SECTION_B_DISCOVERY-handoff.md).
```
