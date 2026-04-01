# Packet 24 — MCP Server, Hook, and Permission Editors

## Context

This packet adds the remaining file editors: MCP server management (add/edit/remove server definitions), hook configuration editing, permission rule editing, and a sandbox configuration editor. Together with Packet 23, these complete the full direct-editing capability.

**Prerequisites: Packets 17, 18, 19, 21 must be complete.**

## Prerequisites

- Packet 17 (atomic write), Packet 18 (edit mode), Packet 21 (permissions inspector) complete

## Deliverables

### 1. MCP Server Editor (`F4`)

Create `ClaudeConfigManager/Features/MCP/MCPServerEditorView.swift`.

This view is a form-based editor for MCP server entries. Present it as a sheet. It handles both adding new servers and editing existing ones.

**Form fields:**

| Field | Input type | Required |
|---|---|---|
| Server ID | `TextField` (monospace) | Required. Must be unique within the scope's file. Emit an error if duplicate. |
| Transport type | `Picker`: stdio / http | Required |
| Command (stdio only) | `TextField` | Required for stdio |
| Arguments (stdio only) | List with add/remove rows | Optional |
| Environment variables (stdio only) | Key-value list editor | Optional |
| URL (http only) | `TextField` with URL validation | Required for http |

**Validation (live, shown inline):**
- Server ID: non-empty, no spaces
- Command (stdio): path format validation (optional — just check non-empty)
- URL (http): must parse as a valid URL with http/https scheme

**"Save" button**: disabled until all required fields are valid. Calls `AtomicFileWriter` targeting either `~/.claude.json` (user scope) or `.mcp.json` (project scope), based on the scope the user is editing. Use the `appendToArray` or `set` operation on the appropriate server list key.

**"Delete" button**: shown when editing an existing server. Requires confirmation. Uses `removeFromArray` operation.

Present from:
- The MCP stage view's server card (an "Edit" button per card)
- An "Add server" button in the MCP stage toolbar, with a scope picker (user vs project)

### 2. Hook Configuration Editor (`F5`)

Create `ClaudeConfigManager/Features/Hooks/HookHandlerEditorView.swift`.

Form-based editor for a single hook handler entry within a specific lifecycle event.

**Form fields:**

| Field | Input type |
|---|---|
| Lifecycle event | `Picker` (all documented events from Packet 05) |
| Handler type | `Picker`: command / http / prompt / agent |
| Timeout (seconds) | `Stepper` (1–300) with `TextField` |
| `once` | `Toggle` (only shown for skills hooks) |
| `shell` | `Picker`: bash / powershell (only for command type) |
| Command (command type) | `TextField` |
| URL (http type) | `TextField` |
| Method (http type) | `Picker`: POST / GET |
| Template (prompt type) | `TextEditor` (short) |
| Agent ID (agent type) | `TextField` |

**Validation**: Required fields per handler type. Show inline error messages.

**Save**: Atomic write via `AtomicFileWriter` to `settings.json` at the appropriate scope. Uses `appendToArray` on the hook event's handler array.

**Delete**: `removeFromArray` on the hook event's handler array.

Present from: the Hooks Lifecycle stage's event rows ("Add handler" button, "Edit" button on existing handlers).

### 3. Permission Rule Editor (`F6`)

Extend the `PermissionsInspectorView` from Packet 21 to support inline editing when Edit Mode (from Packet 18) is active.

**Per-rule row, in edit mode**:
- Edit button (pencil icon) → opens rule editor popover
- Delete button (trash icon) → removes rule with confirmation, atomic write

**Rule editor popover**:
- Rule pattern: `TextField` with a glob pattern example placeholder
- Outcome: `Picker`: deny / ask / allow
- Scope to save to: pre-filled with the scope this rule currently belongs to (or recommendation engine if new)
- "Glob pattern tips" expandable: "Use `bash:*` to match all bash commands. Use `mcp__server__tool` to match a specific MCP tool."

**"Add rule" button** in each outcome group (deny / ask / allow): opens the same popover with the outcome pre-selected.

**Live preview**: as the user types a rule pattern, show a preview: "This rule would match: bash: rm -rf /..." (basic prefix matching against common tool name patterns).

### 4. Sandbox Configuration Editor (`F7`)

Extend `UserSettingsEditorView` with a dedicated "Sandbox" section that uses structured fields instead of raw JSON for the `sandbox` settings family.

Fields per Packet 06's `SandboxDocument`:
- `failIfUnavailable`: `Toggle`
- `allowUnsandboxedCommands`: `Toggle` with a red warning label: "Disabling sandbox protections may allow unintended system access."
- `network.allowedDomains`: a list editor with add/remove rows. Each row has a `TextField` with hostname placeholder. Show a warning for empty strings.
- `network.httpProxyPort` / `socksProxyPort`: `Stepper` + `TextField` with range 1–65535 validation
- `enableWeakerNetworkIsolation`: `Toggle` with amber warning label

All fields write via `AtomicFileWriter` to `settings.json` at the edited scope.

### 5. MCP Card Redesign (K1)

Redesign MCP server entries in the MCP stage view as cards (replaces the current list row style):

Each card:
- Server name (bold)
- Scope badge (coloured pill)
- Transport icon: `terminal` for stdio, `globe` for http
- Validation status: `checkmark.circle.fill` (green) for complete, `exclamationmark.circle.fill` (red) for missing fields
- "Overridden by [scope]" callout if suppressed by a higher scope
- Disclosure group for full config detail
- Edit button (pencil icon, opens `MCPServerEditorView`)

### 6. Tests

- **`testMCPEditorValidatesUniqueId`** — add a server with an ID that already exists → save button disabled
- **`testHookEditorRequiresCommandForCommandType`** — command type with empty command → save disabled
- **`testPermissionRuleEditorGlobPreview`** — type `bash:*` → preview shows "matches all bash commands"

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- MCP server editor adds/edits/removes servers atomically
- Hook editor adds handlers for any lifecycle event
- Permission rule editor adds/removes rules inline in the Permissions view
- Sandbox settings use structured fields with appropriate warnings
- MCP cards show scope badge, transport icon, and validation status
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/24-handoff.md` if work deviated from the plan. Record what was completed, what was not, and recommended next step.
