# Packet 09 — Managed Tier Resolution and UI

## Context

Packet 08 made managed files discoverable. This packet wires them into the resolver so managed settings actually win over user/project settings, and replaces the current managed scope placeholder view with a real, functional UI.

**Prerequisites: Packets 01, 03, 07, and 08 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 03 (key registry), Packet 07 (schema validation), Packet 08 (managed discovery) complete

## Deliverables

### 1. Understand the existing managed resolver

Read `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` in full. Understand:
- How `ResolutionScope` models managed vs. non-managed tiers
- How the existing managed scope view currently populates its data (it does show some data today)
- How `SettingsResolver.resolvePrecedence()` orders scopes

### 2. Implement "first tier wins" for managed settings

Within the managed tier, three sub-tiers exist: server-managed (highest), MDM/plist, file-based. Implement this ordering:

Create `ManagedSettingsResolver.swift` in `Infrastructure/Resolver/`:

```swift
struct ManagedSettingsResolver {
    /// Given scan results from all managed sources, produce a single
    /// SettingsSourceCandidate representing the winning managed value per key.
    func resolve(
        serverManaged: SettingsDocument?,   // server-managed (if applicable)
        mdm: MDMSettingsResult?,             // MDM plist result
        fileBase: SettingsDocument?,         // managed-settings.json
        fileOverrides: [SettingsDocument]   // managed-settings.d/*.json merged lexicographically
    ) -> ResolvedManagedSettings
}

struct ResolvedManagedSettings {
    var entries: [String: ManagedSettingsEntry]
}

struct ManagedSettingsEntry {
    var value: JSONValue
    var winningSubTier: ManagedSubTier
    var source: String   // file path or "MDM"
}

enum ManagedSubTier {
    case serverManaged, mdm, fileBased
}
```

**File-based sub-tier merge**: merge `fileBase` and all `fileOverrides` files. For each key: the value from the alphabetically-last file in `managed-settings.d/` wins (if present), otherwise `fileBase` wins. This is a simple lexicographic "last file wins" merge.

**Cross-sub-tier priority**: serverManaged > mdm > fileBased. For each key, take the value from the highest sub-tier that defines it.

### 3. Register managed as highest-precedence scope in `SettingsResolver`

In `SettingsResolver.resolvePrecedence()`, ensure the managed tier's resolved entries beat all other scopes for any key defined at managed level. The existing code may already have a placeholder for this — read it first. Update it to use the new `ManagedSettingsResolver` output.

All existing resolver tests must remain green.

### 4. Add resolver tests for managed precedence

Add to `ClaudeConfigManagerTests/`:

- **`testManagedBeatsUser`** — a key defined at both managed and user scope → managed value wins
- **`testManagedBeatsProject`** — same for project scope
- **`testMDMBeatsFileBased`** — within managed tier, MDM value beats file-based
- **`testFileOverrideBeatBase`** — within file-based managed, `managed-settings.d/b.json` beats `managed-settings.json` for a shared key

### 5. Replace the managed placeholder view

Find the current managed scope view in `ClaudeConfigManager/Features/Managed/`. Replace its placeholder content with a real view using the resolved managed data.

**The new managed view must show:**

1. **Active managed tier indicator** — which sub-tier is providing data: "Server-Managed Policy", "MDM Policy (com.anthropic.claudecode)", or "File-Based Managed Settings". If none, show a positive "No managed policy active" empty state.

2. **Source label** — the file path or MDM domain for the winning sub-tier.

3. **Managed settings list** — a list of all keys defined at managed scope, each row showing:
   - Key name (monospace)
   - Value
   - Sub-tier badge (Server / MDM / File)
   - Lock icon (SF Symbol `lock.fill`) to visually communicate the locked nature

4. **"Managed policy locks X settings" summary** — a count badge at the top of the list.

5. **Empty state** — if no managed config files exist and no MDM domain is present, show: "No managed policy is active on this machine. Managed settings would override all user and project configuration."

Apply `ScopeColorScheme.color(for: .managed)` for all managed-scope badges and colour accents.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All resolver tests pass including new managed precedence tests
- All existing tests pass
- The managed scope view renders real data (or a sensible empty state) instead of placeholder text
- Build has zero warnings

## Handover Note

Only create `Documents/09-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complications with the existing managed scope view or resolver structure, and recommended next step.
