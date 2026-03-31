# Packet S3: Sandbox Configuration

## Overview

This packet adds a dedicated nested sandbox model covering the full 21-key sandbox surface as documented in Claude Code settings (March 2026). Sandbox is a structured configuration family with nested filesystem and network sub-objects.

**This is the largest parser packet by key count (21 keys).** Consider splitting into S3a (top-level + filesystem) and S3b (network + managed-only validation) if implementation time is constrained.

## Prerequisites

- G1 and G2 completed (registry and typed accessors)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11 (Sandbox keys)

## Full key inventory

### Top-level sandbox keys (7 keys)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `sandbox.enabled` | `Bool` | false | Enable bash sandboxing |
| `sandbox.failIfUnavailable` | `Bool` | false | Exit with error if sandbox can't start |
| `sandbox.autoAllowBashIfSandboxed` | `Bool` | true | Auto-approve bash when sandboxed |
| `sandbox.excludedCommands` | `[String]` | [] | Commands outside sandbox |
| `sandbox.allowUnsandboxedCommands` | `Bool` | true | Allow `dangerouslyDisableSandbox` |
| `sandbox.enableWeakerNestedSandbox` | `Bool` | false | Weaker sandbox for Docker (Linux/WSL2) |
| `sandbox.enableWeakerNetworkIsolation` | `Bool` | false | TLS trust service access (macOS) |

### Filesystem child keys (5 keys)

| Key | Type | Merge | Description |
|-----|------|-------|-------------|
| `sandbox.filesystem.allowWrite` | `[String]` | Append+dedup | Additional writable paths |
| `sandbox.filesystem.denyWrite` | `[String]` | Append+dedup | Blocked write paths |
| `sandbox.filesystem.denyRead` | `[String]` | Append+dedup | Blocked read paths |
| `sandbox.filesystem.allowRead` | `[String]` | Append+dedup | Re-allowed reads (overrides denyRead) |
| `sandbox.filesystem.allowManagedReadPathsOnly` | `Bool` | — | Managed only: ignore non-managed allowRead |

### Network child keys (9 keys)

| Key | Type | Merge | Description |
|-----|------|-------|-------------|
| `sandbox.network.allowUnixSockets` | `[String]` | Append+dedup | Accessible Unix socket paths |
| `sandbox.network.allowAllUnixSockets` | `Bool` | — | Allow all Unix sockets |
| `sandbox.network.allowLocalBinding` | `Bool` | — | Bind to localhost (macOS) |
| `sandbox.network.allowedDomains` | `[String]` | Append+dedup | Outbound domains (wildcards) |
| `sandbox.network.allowManagedDomainsOnly` | `Bool` | — | Managed only: ignore non-managed domains |
| `sandbox.network.httpProxyPort` | `Int` | — | Custom HTTP proxy port |
| `sandbox.network.socksProxyPort` | `Int` | — | Custom SOCKS5 proxy port |

### Path prefix rules

| Prefix | Meaning |
|--------|---------|
| `/` | Absolute path |
| `~/` | Relative to home |
| `./` or none | Relative to project root (project) or `~/.claude` (user) |

Array settings merge across scopes (concat + dedup). Also merge with `Edit(...)` allow/deny and `Read(...)` deny permission rules.

## Deliverables

### 1. Model types

```swift
struct ParsedSandboxConfig {
    let enabled: Bool?
    let failIfUnavailable: Bool?
    let autoAllowBashIfSandboxed: Bool?
    let excludedCommands: [String]?
    let allowUnsandboxedCommands: Bool?
    let enableWeakerNestedSandbox: Bool?
    let enableWeakerNetworkIsolation: Bool?
    let filesystem: ParsedSandboxFilesystem?
    let network: ParsedSandboxNetwork?
    let unknownFields: [String: JSONValue]?
}

struct ParsedSandboxFilesystem {
    let allowWrite: [String]?
    let denyWrite: [String]?
    let denyRead: [String]?
    let allowRead: [String]?
    let allowManagedReadPathsOnly: Bool?
    let unknownFields: [String: JSONValue]?
}

struct ParsedSandboxNetwork {
    let allowUnixSockets: [String]?
    let allowAllUnixSockets: Bool?
    let allowLocalBinding: Bool?
    let allowedDomains: [String]?
    let allowManagedDomainsOnly: Bool?
    let httpProxyPort: Int?
    let socksProxyPort: Int?
    let unknownFields: [String: JSONValue]?
}
```

### 2. Parser updates

- Parse `sandbox` as JSON object
- Parse nested `filesystem` and `network` as child objects
- Type-check all 21 keys
- Preserve unknown keys at each nesting level
- Emit error for non-object `sandbox` / `filesystem` / `network`
- Emit warning for managed-only keys in non-managed scope (defer if scope unavailable)

### 3. Registry entries (if G1 done)

Register all 21 keys: category `sandbox`, merge hints `appendUnique` for arrays, `selectHighestPrecedence` for scalars. Flag managed-only for `allowManagedReadPathsOnly` and `allowManagedDomainsOnly`.

### 4. Fixtures

**`valid_sandbox_full/input/settings.json`:**
```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "git"],
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "allowWrite": ["/tmp/build", "~/.kube"],
      "denyWrite": ["/etc"],
      "denyRead": ["~/.aws/credentials"],
      "allowRead": ["."]
    },
    "network": {
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": true,
      "allowedDomains": ["github.com", "*.npmjs.org"],
      "httpProxyPort": 8080,
      "socksProxyPort": 8081
    }
  }
}
```

**`valid_sandbox_minimal/input/settings.json`:**
```json
{ "sandbox": { "enabled": true } }
```

**`invalid_sandbox_shapes/input/settings.json`:**
```json
{
  "sandbox": {
    "enabled": "yes",
    "excludedCommands": "docker",
    "filesystem": "not-an-object",
    "network": { "httpProxyPort": "bad", "allowedDomains": 42 }
  }
}
```

### 5. Tests

- Full 21-key parsing
- Minimal sandbox (only `enabled`)
- Partial nested objects
- Type mismatches at all 3 levels
- Unknown field preservation
- Non-object parent values → error

## Acceptance criteria

- [ ] All 21 sandbox keys parse into typed structures
- [ ] Nested filesystem/network parse independently
- [ ] Type mismatches → warning issues
- [ ] Non-object parents → error issues
- [ ] Unknown keys preserved at all levels
- [ ] Managed-only keys flagged
- [ ] Full test suite passes
