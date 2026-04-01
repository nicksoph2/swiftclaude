# Packet 18 — Edit Mode, Scope Recommendation Engine, and Managed Locks

## Context

Packets 17 built the atomic write infrastructure. This packet adds the user-facing editing interface: an Edit Mode toggle on the resolved settings view, the scope recommendation engine that suggests where to save a setting, and the managed lock indicators that prevent editing managed-controlled settings.

**Prerequisites: Packets 01, 03, 07, 09, 15, 17 must be complete.**

## Prerequisites

- Packet 17 (atomic write), Packet 15 (resolution trace), Packet 09 (managed resolver) complete

## Deliverables

### 1. `ScopeRecommendationEngine.swift`

Create `ClaudeConfigManager/Infrastructure/ScopeRecommendationEngine.swift`.

```swift
struct ScopeRecommendationEngine {
    func recommend(
        for keyPath: String,
        currentProjection: SessionProjection,
        availableScopes: [ResolutionScope]
    ) -> ScopeRecommendation
}

struct ScopeRecommendation {
    let recommendedScope: ResolutionScope
    let rationale: String       // plain-English, one sentence
    let isEditable: Bool        // false if managed-locked
    let lockInfo: ManagedLockInfo?
}

struct ManagedLockInfo {
    let controllingTier: ManagedSubTier
    let sourcePath: String      // file path or "MDM"
    let enforcedValue: JSONValue
}
```

**Recommendation rules** (in order):

1. If the key is defined at the managed scope → `isEditable = false`, return `lockInfo`
2. If the key is already defined at one writable scope (user/project/project-local) → recommend that scope. Rationale: "This setting already exists at [scope name]. Editing here updates it in place."
3. If not defined anywhere, use the key's `ScopeRestriction` from the registry:
   - Personal preference keys (UISettings, ModelSettings for personal use) → recommend `.user`. Rationale: "This is a personal preference. Saving here applies it to all your projects."
   - Project behaviour keys (PermissionSettings, HookPolicySettings, MCPPolicySettings) → recommend `.project`. Rationale: "This setting affects how Claude behaves in this project. Saving here shares it with your team."
4. If `availableScopes` does not include the recommended scope, fall back to the next available scope.

### 2. Edit Mode toggle

In the resolved settings views (at minimum the Resolution stage view, and ideally also the User/Project scope views), add an "Edit" toolbar button.

When Edit Mode is active:
- A banner appears below the toolbar: "Edit Mode — changes will be saved to your configuration files." with a "Done" button
- Each setting row gains an edit indicator:
  - For editable settings: a pencil icon at the trailing edge of the row
  - For managed-locked settings: a lock icon (`lock.fill`) in the managed scope colour (red)
- Tapping an editable row opens the editor popover (see below)
- Tapping a locked row opens the lock detail popover

When Edit Mode is inactive (default): rows are display-only, no affordances shown.

### 3. Editor popover

When an editable setting row is tapped in Edit Mode, present a compact popover anchored to the row:

**Popover contents:**
- Key name (monospace, bold)
- "Current value:" — the effective value (read-only display)
- "Source:" — winning scope and file path
- Divider
- "New value:" — type-appropriate input field:
  - String → `TextField`
  - Bool → `Toggle`
  - Int/Double → `Stepper` + `TextField`
  - Enum → `Picker` with the registry's `validValues`
  - Array → a simple list with add/remove buttons (advanced; if complex, fall back to a text field for this packet)
- Divider
- "Save to:" — scope picker showing all writable scopes, with the recommended scope pre-selected and labelled "(recommended)"
- "Why recommended?" — the rationale string from `ScopeRecommendationEngine` in secondary text
- Divider
- Two buttons: "Preview Impact" (disabled for now — will be wired in Packet 19) and "Save"

"Save" calls `AtomicFileWriter.write(change:to:at:)` with the selected scope's file URL. Show a progress indicator while saving. On success, dismiss the popover. On error, show the `WriteError` description in an alert.

### 4. Managed lock popover

When a managed-locked row is tapped in Edit Mode, present a small popover:

- Lock icon (large, in managed scope colour)
- Title: "Set by managed policy"
- Body: "This setting is controlled by [tier name] from [source]. You cannot override it at this level."
- "Enforced value:" with the value shown
- No edit affordance

### 5. Simplified scope picker (F2-7)

By default, the scope picker in the editor popover shows simplified labels:
- "This project only" → routes to `.project` scope
- "All my projects" → routes to `.user` scope

An "Advanced options" disclosure group expands to show all six scopes with their technical names.

`@AppStorage("useSimplifiedScopePicker")` defaults to `true`. Once the user expands advanced options and selects a non-simplified scope, set to `false` for future opens.

### 6. Tests

Create `ClaudeConfigManagerTests/Infrastructure/ScopeRecommendationEngineTests.swift`:

- **`testManagedKeyIsNotEditable`** — key with managed value → `isEditable == false`
- **`testExistingUserScopeKeyRecommendsUser`** — key already at user scope → recommends `.user`
- **`testPersonalPreferenceKeyRecommendsUser`** — key not yet defined, personal preference category → recommends `.user`
- **`testProjectBehaviourKeyRecommendsProject`** — key not yet defined, project behaviour category → recommends `.project`

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Edit Mode toggle appears in the settings view toolbar
- Editable rows show pencil icon; managed rows show lock icon
- Editor popover opens on row tap in Edit Mode
- Recommended scope is pre-selected with rationale text
- "Save" writes via `AtomicFileWriter` and the view refreshes
- Managed lock popover explains which tier controls the setting
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/18-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complications with the popover anchoring or save flow, and recommended next step.
