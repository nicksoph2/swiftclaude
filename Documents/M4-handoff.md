# M4 Handoff — Sandbox Entitlements and Managed Access Fallback

## Files created or modified

| File | Change |
|------|--------|
| `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift` | Added `ManagedAccessOutcome`, `SandboxProbing`, `SystemSandboxProbe`, and `ManagedSettingsLocator.probeManagedAccessOutcome(sandboxProbe:)` |
| `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` | Extended `ManagedScopeStatusModel` with `accessOutcome: ManagedAccessOutcome`; added `init(resolution:accessOutcome:)` while preserving backward-compatible `init(resolution:)` |
| `ClaudeConfigManager/Features/Managed/ManagedScopeView.swift` | Added explicit `accessFallbackCard` that renders when `accessOutcome.requiresExplicitFallbackUI` is `true`; updated header copy for clarity |
| `ClaudeConfigManagerTests/Discovery/WorkspaceScannerTests.swift` | Added 8 new tests in `ManagedSettingsLocatorTests` covering all `probeManagedAccessOutcome` branches; added `MockSandboxProbe` test double |
| `Documents/M4-handoff.md` | This file |

## Entitlement status

The existing `ClaudeConfigManager.entitlements` already contains the correct App Store-safe set:
- `com.apple.security.app-sandbox = true`
- `com.apple.security.files.bookmarks.app-scope = true`
- `com.apple.security.files.user-selected.read-only = true`

No new entitlements were added. The spec says not to add privileged helpers or temporary-exception entitlements. For the managed system path (`/Library/Application Support/ClaudeCode/`), standard App Store sandbox policy does not grant access, and that limitation is now surfaced explicitly in the UI rather than being a silent omission.

## Key decisions and assumptions

### `ManagedAccessOutcome` cases
Four cases were defined:
- **`.accessible`** — root directory is readable; managed files may be present.
- **`.missing`** — root doesn't exist and process is not sandboxed; no managed policy has been deployed.
- **`.sandboxRestricted`** — sandboxed process; cannot distinguish genuine absence from a sandbox-hidden path. This is the correct outcome whenever the process is sandboxed and access fails, because macOS sandbox hides out-of-container paths as ENOENT rather than EPERM.
- **`.inaccessible(diagnostics:)`** — non-sandbox access failure (wrong permissions, path is a file instead of a directory, unexpected node type).

### Sandbox detection strategy
`SystemSandboxProbe` reads `APP_SANDBOX_CONTAINER_ID` from `ProcessInfo.processInfo.environment`. The OS sets this variable for every sandboxed process. This is the standard way to detect macOS sandbox at runtime without using private APIs.

### Sandbox + missing = sandboxRestricted
When the process is sandboxed and the managed root path appears missing, the outcome is `.sandboxRestricted` rather than `.missing`. This is intentional: a sandbox profile that does not allow access to `/Library/Application Support/ClaudeCode/` causes the OS to return `ENOENT` (path hidden), not `EPERM`. The app cannot tell whether policy has been deployed; surfacing `.sandboxRestricted` is more honest than silently claiming no policy is present.

### `ManagedScopeStatusModel` backward compatibility
The existing `init(resolution:)` now delegates to `init(resolution:accessOutcome:)` with a default of `.missing`. All existing call sites compile without change.

### `ManagedScopeView` fallback card
The `accessFallbackCard` appears conditionally via `accessOutcome.requiresExplicitFallbackUI`. It is shown for `.sandboxRestricted` (orange, lock-shield icon) and `.inaccessible` (red, warning icon). It is hidden for `.accessible` and `.missing`, which are normal states requiring no extra explanation.

### New code lives in existing files
Following the M1 precedent, all new types were added to existing compiled source files to avoid creating uncompiled file references in the Xcode project. `ManagedAccessOutcome`, `SandboxProbing`, `SystemSandboxProbe`, and the `ManagedSettingsLocator` extension all live in `WorkspaceScanner.swift`.

## Verification

`xcodebuild` is not available in the agent sandbox environment. The test suite must be run on Nick's Mac:

```bash
cd /Users/nicksoph/Documents/Dev/claude/devDiscoverApp
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

Manual review confirms:
- All `ManagedSettingsNodeStatus` switch cases exhaustively covered in `probeManagedAccessOutcome`
- `fileprivate discoverySnapshot()` is accessible within the same file
- `private ManagedSettingsNodeStatus` is accessible within the same file (top-level private)
- `AnyShapeStyle` conforms to `ShapeStyle` and works with the `.background(_:in:)` modifier
- `MockSandboxProbe` satisfies `SandboxProbing` via `@testable import ClaudeConfigManager`

## Issues encountered or open questions

1. **Runtime wiring not yet connected**: `probeManagedAccessOutcome()` is callable but no code in the app shell currently calls it and passes the result into `ManagedScopeStatusModel`. The wiring from `WorkspaceScanner` → `ManagedScopeStatusModel` → `ManagedScopeView` will be done in the runtime/app-shell composition layer (a future packet, not M4 scope).

2. **Sandbox hides managed config as missing**: In a real App Store build where managed policy *has* been deployed, the app will show "Managed path not accessible in sandbox" even though policy exists. This is the honest and correct behaviour; there is no App Store-safe way to read `/Library/Application Support/ClaudeCode/` without a privileged helper (which the spec explicitly prohibits).

3. **Managed CLAUDE.md still unimplemented**: The M1 handoff noted that `/Library/Application Support/ClaudeCode/CLAUDE.md` was deferred. M4 does not add it either — it is out of M4 scope.

## Recommended next packet

- **R1** — Resolver models (settings resolution pipeline), now that the managed tier models from M1–M4 are complete.
- Alternatively **V4** — Managed scope view, which would wire the full managed pipeline into the UI using the `ManagedScopeStatusModel` + `accessOutcome` added in M4.
