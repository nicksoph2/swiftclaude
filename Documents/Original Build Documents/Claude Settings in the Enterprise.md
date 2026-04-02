# Claude Settings in the Enterprise

## Purpose of This Document

Claude Config Manager is a sandboxed macOS App Store application that inspects Claude Code configuration. Because it runs inside the macOS App Sandbox, it cannot freely read files on disk the way Claude Code itself can. This document explains what enterprise-managed configuration exists, what this app can and cannot see, and what an MDM administrator can do to ensure full visibility.

---

## How Claude Code Receives Managed Configuration

Claude Code can receive enterprise configuration through three independent channels. Each has a different level of accessibility from a sandboxed third-party app.

### Channel 1: Server-Managed Settings (Anthropic Cloud)

An organisation admin configures settings in the Claude.ai admin console (Admin Settings → Claude Code → Managed settings). Claude Code fetches this configuration over an authenticated API at startup and polls hourly, caching it locally.

**Accessibility from this app: None.** Server-managed settings are delivered over Anthropic's authenticated API. No third-party app can read them. When server-managed settings are active, they take precedence over all endpoint-managed settings — the two sources do not merge. This means that if an organisation relies exclusively on server-managed settings, this app has no visibility into the managed configuration actually governing Claude Code's behaviour.

### Channel 2: macOS Managed Preferences (MDM Configuration Profiles)

An MDM administrator creates a configuration profile targeting the `com.anthropic.claudecode` preference domain and pushes it to managed devices via Jamf, Kandji, Intune, Mosyle, or any other MDM platform. The profile installs to `/var/db/profiles/` and macOS makes the values available through the `CFPreferences` API.

**Accessibility from this app: Full, automatic, no user interaction required.** A sandboxed App Store app can read managed preference domains using `CFPreferencesCopyValue` with `kCFPreferencesAnyUser` and `kCFPreferencesCurrentHost`. No bookmark, entitlement, or user prompt is needed. This is the most transparent channel for this app.

### Channel 3: File-Based Managed Settings (on-disk JSON)

An MDM administrator deploys JSON configuration files to the filesystem, typically to `/Library/Application Support/ClaudeCode/`. These files are written by installer packages or MDM scripts running as root.

**Accessibility from this app: Requires a one-time security-scoped bookmark.** The user must grant access to `/Library/Application Support/ClaudeCode/` via an Open panel. Once granted, the bookmark persists across app launches. If this bookmark has not been granted, the app cannot read any file-based managed configuration.

---

## What Lives Where

### Managed Preferences Domain (`com.anthropic.claudecode`)

The MDM configuration profile can carry any key from the Claude Code settings schema. In practice, administrators typically use it for policy and lockdown settings. The full set of configurable keys includes:

**Authentication & Identity**

| Key | Type | Purpose |
|-----|------|---------|
| `forceLoginMethod` | `"claudeai"` or `"console"` | Require a specific OAuth provider |
| `forceLoginOrgUUID` | String | Lock authentication to a specific organisation |

**Permissions & Security**

| Key | Type | Purpose |
|-----|------|---------|
| `permissions.allow` | Array of strings | Tool patterns always permitted (e.g. `Bash(npm run *)`) |
| `permissions.deny` | Array of strings | Tool patterns always blocked (e.g. `Read(./.env)`) |
| `permissions.ask` | Array of strings | Tool patterns requiring user confirmation |
| `permissions.defaultMode` | String | Default permission mode (`acceptEdits`, `bypassPermissions`, `default`, `plan`, `dontAsk`) |
| `permissions.disableBypassPermissionsMode` | `"disable"` | Prevent users from enabling bypass mode |
| `permissions.disableAutoMode` | `"disable"` | Prevent users from enabling auto mode |

**Sandbox Restrictions**

| Key | Type | Purpose |
|-----|------|---------|
| `sandbox.enabled` | Boolean | Enable/disable the sandbox |
| `sandbox.network.allowedDomains` | Array | Domains Claude Code can reach |
| `sandbox.network.denyDomains` | Array | Domains explicitly blocked |
| `sandbox.network.allowManagedDomainsOnly` | Boolean | Only allow admin-specified domains |
| `sandbox.filesystem.allowRead` | Array | Paths Claude Code may read |
| `sandbox.filesystem.denyRead` | Array | Paths explicitly unreadable |
| `sandbox.filesystem.allowWrite` | Array | Paths Claude Code may write |
| `sandbox.filesystem.denyWrite` | Array | Paths explicitly unwritable |
| `sandbox.filesystem.allowManagedReadPathsOnly` | Boolean | Only allow admin-specified read paths |

**Managed-Only Lockdown Flags**

These keys are only honoured when delivered via a managed channel. Claude Code ignores them in user or project settings.

| Key | Type | Purpose |
|-----|------|---------|
| `allowManagedHooksOnly` | Boolean | Prevent user/project/plugin-defined hooks |
| `allowManagedMcpServersOnly` | Boolean | Only allow admin-defined MCP servers |
| `allowManagedPermissionRulesOnly` | Boolean | Only admin permission rules apply |
| `blockedMarketplaces` | Array | Plugin marketplaces users cannot access |
| `strictKnownMarketplaces` | Array | Only these marketplaces are allowed |
| `channelsEnabled` | Boolean | Enable/disable channels for Team/Enterprise |
| `pluginTrustMessage` | String | Custom warning shown when installing plugins |
| `allowedChannelPlugins` | Array | Channel plugin allowlist |

**Operational Defaults**

| Key | Type | Purpose |
|-----|------|---------|
| `model` | String | Default model override |
| `availableModels` | Array | Restrict which models users may select |
| `effortLevel` | `"low"`, `"medium"`, `"high"` | Default thinking effort |
| `autoUpdatesChannel` | `"stable"` or `"latest"` | Update channel |
| `autoMemoryEnabled` | Boolean | Auto-save context between sessions |
| `language` | String | Preferred response language |
| `cleanupPeriodDays` | Number | Chat transcript retention (default: 30) |

**Hooks**

| Key | Type | Purpose |
|-----|------|---------|
| `hooks.PreToolUse` | Array | Run before a tool executes |
| `hooks.PostToolUse` | Array | Run after a tool executes |
| `hooks.PermissionRequest` | Array | Run when permission is requested |
| `hooks.UserPromptSubmit` | Array | Run when user submits a prompt |
| `hooks.SessionStart` | Array | Run when a session begins |
| `hooks.SessionEnd` | Array | Run when a session ends |
| `hooks.Notification` | Array | Run on notifications |
| `hooks.Stop` | Array | Run when Claude stops |

Each hook entry can be of type `command` (shell), `prompt` (LLM), `agent` (multi-turn), or `http` (webhook).

**Environment & Plugins**

| Key | Type | Purpose |
|-----|------|---------|
| `env` | Object | Environment variables injected into Claude Code sessions |
| `enabledPlugins` | Array | Plugins to load (format: `plugin@marketplace`) |
| `extraKnownMarketplaces` | Array | Additional plugin sources |
| `pluginConfigs` | Object | Per-plugin MCP server configuration |
| `apiKeyHelper` | String | Shell script that returns API keys |

### File-Based Managed Settings (`/Library/Application Support/ClaudeCode/`)

| File | Purpose |
|------|---------|
| `managed-settings.json` | Primary managed configuration — same schema as above |
| `managed-settings.d/*.json` | Drop-in fragments, sorted alphabetically and merged on top of `managed-settings.json` |
| `managed-mcp.json` | MCP server definitions that are always loaded |
| `CLAUDE.md` | Managed instructions always prepended to Claude's context |

The drop-in directory (`managed-settings.d/`) follows the systemd convention: files are processed in lexicographic order, and later files override earlier ones. This allows different teams or policies to contribute independent configuration fragments.

### Additional Managed Paths

On some deployments, particularly those following Linux conventions, managed files may also appear at:

| Path | Purpose |
|------|---------|
| `/etc/claude-code/managed-settings.json` | Alternative managed settings location |
| `/etc/claude-code/CLAUDE.md` | Global policy instructions |
| `/etc/claude-code/rules/*.md` | Global policy rule files |

These paths require their own security-scoped bookmark if the app is to read them.

---

## Precedence Hierarchy

When Claude Code resolves its effective configuration, sources are evaluated in this order (highest priority first):

1. **Server-managed** (Anthropic cloud) — if present, endpoint-managed settings are ignored entirely
2. **MDM / OS managed preferences** (`com.anthropic.claudecode` domain)
3. **File-based managed settings** (`managed-settings.json` + drop-ins)
4. **User settings** (`~/.claude/settings.json`)
5. **Project settings** (`.claude/settings.json`)
6. **Project local settings** (`.claude/settings.local.json`)
7. **Built-in defaults**

Array-valued settings (such as `permissions.allow` or `sandbox.filesystem.allowWrite`) are concatenated and deduplicated across scopes, not replaced.

**Critical implication for this app:** If an organisation uses server-managed settings (channel 1), those settings silently override everything in channels 2 and 3. This app cannot detect whether server-managed settings are active, nor read their contents. The configuration this app displays may therefore not reflect what Claude Code is actually using.

---

## What This App Can and Cannot Show

| Configuration Source | Can This App Read It? | Conditions |
|---|---|---|
| MDM managed preferences | Yes | Always — no user action needed |
| `/Library/Application Support/ClaudeCode/` files | Yes | After user grants bookmark (once) |
| `/etc/claude-code/` files | Yes | After user grants bookmark (once) |
| Server-managed settings (Anthropic cloud) | **No** | Not accessible to third-party apps |
| User settings (`~/.claude/`) | Yes | After user grants bookmark (once) |
| Project settings (`.claude/` in project root) | Yes | After user grants bookmark per project |

### Gaps in Visibility

1. **Server-managed settings are invisible.** If the organisation delivers configuration via the Claude.ai admin console, this app cannot see it. There is no workaround — these settings are fetched over an authenticated channel that only Claude Code itself can access.

2. **MDM preferences may be incomplete.** An administrator might use MDM preferences for some settings and server-managed for others. This app can only show the MDM portion.

3. **File-based settings require explicit access.** Until the user grants a bookmark to `/Library/Application Support/ClaudeCode/`, the app cannot confirm whether file-based managed settings exist, nor read their contents.

4. **Effective resolution is approximate.** Because this app cannot see server-managed settings, it cannot compute the true effective configuration. It can only show what it can see and note where gaps exist.

---

## Recommendations for MDM Administrators

To ensure this app has full visibility into the managed configuration governing Claude Code, an administrator should take the following steps.

### Use Endpoint-Managed Settings Instead of (or In Addition to) Server-Managed

Server-managed settings are opaque to any tool running on the device. If full local auditability is a requirement, deliver all managed configuration through MDM preferences or file-based settings. If server-managed settings must be used, mirror them into the endpoint-managed channel so that local tools can inspect them.

### Deploy Configuration via Both MDM Preferences and Files

MDM preferences are the easiest for this app to read (no user interaction), but they are less suited to large or complex configurations. File-based settings support the drop-in directory pattern and can carry `managed-mcp.json` and `CLAUDE.md`, which have no equivalent in the preference domain. The recommended approach:

- **MDM preferences** for policy flags, authentication settings, and lockdown keys — anything this app should be able to read without any user action.
- **File-based settings** for the full configuration, including MCP servers, hooks, managed instructions, and drop-in fragments.

Claude Code merges both sources (MDM preferences take precedence over file-based within the managed tier), so deploying to both channels is safe and provides redundancy.

### Ensure the Managed Files Directory Exists Before the User Opens This App

This app uses `FileManager.default.fileExists(atPath:)` to detect whether `/Library/Application Support/ClaudeCode/` is present. In the App Sandbox, this call returns `false` for paths the app cannot access — so the app cannot distinguish "directory does not exist" from "directory exists but is sandboxed away". If the directory is created by a post-enrolment script before the user first launches this app, the onboarding flow can guide the user to grant access. If the directory is created later, the user may need to be prompted again.

To create the directory during MDM enrolment, include a script or package payload that runs:

```bash
mkdir -p "/Library/Application Support/ClaudeCode"
chown root:wheel "/Library/Application Support/ClaudeCode"
chmod 755 "/Library/Application Support/ClaudeCode"
```

### Use the Drop-In Directory for Modular Policy

Rather than maintaining a single large `managed-settings.json`, use the `managed-settings.d/` directory to separate concerns:

```
/Library/Application Support/ClaudeCode/
├── managed-settings.json          (base: authentication, model defaults)
├── managed-settings.d/
│   ├── 10-security-policy.json    (permissions, sandbox, lockdown flags)
│   ├── 20-network-policy.json     (allowed domains, proxy settings)
│   ├── 30-plugin-policy.json      (marketplace restrictions, enabled plugins)
│   └── 90-team-overrides.json     (team-specific customisations)
├── managed-mcp.json               (MCP server definitions)
└── CLAUDE.md                      (managed instructions)
```

Files are sorted alphabetically and merged in order, so numeric prefixes control precedence. This app reads and displays each drop-in file individually, making it easier to audit which policy fragment contributes which setting.

### Expose MDM Preferences for Key Lockdown Flags

At minimum, the following keys should be present in the MDM configuration profile so that this app can confirm the security posture without needing filesystem access:

```xml
<key>PayloadType</key>
<string>com.anthropic.claudecode</string>
<key>allowManagedHooksOnly</key>
<true/>
<key>allowManagedMcpServersOnly</key>
<true/>
<key>allowManagedPermissionRulesOnly</key>
<true/>
<key>sandbox.enabled</key>
<true/>
<key>sandbox.network.allowManagedDomainsOnly</key>
<true/>
<key>sandbox.filesystem.allowManagedReadPathsOnly</key>
<true/>
<key>permissions.disableBypassPermissionsMode</key>
<string>disable</string>
<key>forceLoginMethod</key>
<string>claudeai</string>
<key>forceLoginOrgUUID</key>
<string>your-org-uuid-here</string>
```

This gives the app enough information to confirm that the lockdown policies are active, even if the detailed permission rules and MCP server definitions are only available via the filesystem.

### Consider Granting the Bookmark During Onboarding

If the organisation distributes this app via MDM alongside Claude Code, the IT team can include a step in the user onboarding guide instructing them to grant filesystem access when first launching the app. Once the bookmark is saved, no further interaction is needed. The bookmark persists across app updates (it is stored in the app's own sandboxed container, which survives updates from the App Store).

---

## Summary

This app provides the most complete view of Claude Code's configuration when the organisation delivers managed settings through endpoint channels (MDM preferences and/or filesystem) rather than server-managed settings. An MDM administrator who mirrors all configuration into both the `com.anthropic.claudecode` preference domain and the `/Library/Application Support/ClaudeCode/` file tree ensures that this app can display the full managed configuration with no gaps. Server-managed settings remain the one blind spot that cannot be addressed from outside Claude Code itself.
