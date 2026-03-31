# Packet T3: Telemetry / OpenTelemetry Configuration Display (Optional)

## Overview

This packet adds optional support for detecting and displaying the OpenTelemetry (OTel) configuration that Claude Code uses for telemetry export. This packet is explicitly optional and should not interfere with normal operation if OTel is not configured.

**Important architectural correction:** Claude Code's OTel integration is a **push-only** model — it exports metrics and events to external collectors via standard OTLP protocol. The app **cannot query an OTel collector** for data. There is no standard read API from an OTel collector that the app could use to retrieve spans or metrics.

This packet therefore focuses on:
1. **Detecting** whether OTel is configured (from settings and environment variables)
2. **Displaying** the OTel configuration state to the user (what's being exported, where, and how)
3. **Explaining** privacy and correlation implications (for example whether prompt contents or tool details may be exported)
4. **Documenting** what metrics, events, and correlation attributes Claude Code emits (informational reference)

OTel is therefore a **supplementary observability surface** in this app. Session state, prompt history, token totals, and cost views should continue to come from status-line data and transcripts first; OTel is used to explain telemetry configuration and what Claude Code would emit if telemetry is enabled.

This packet does NOT:
- Make HTTP requests to OTel collector endpoints
- Ingest or display OTel spans, metrics, or events
- Query any external telemetry backend

## Prerequisites

- App shell exists
- Settings parsing covers the `env` key and `otelHeadersHelper` key
- G1/G2 registry work covers environment variable settings

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift` — for env/otelHeadersHelper detection
- Claude Code monitoring docs: https://code.claude.com/docs/en/monitoring-usage

## How OTel is configured in Claude Code

Claude Code's telemetry is configured via **environment variables**, not structured JSON settings objects. The only settings.json key directly related to OTel is `otelHeadersHelper`.

### `otelHeadersHelper` (settings.json)

This is a **string** containing a script path, NOT an object with endpoint/headers:

```json
{
  "otelHeadersHelper": "/bin/generate_opentelemetry_headers.sh"
}
```

The script must output valid JSON with string key-value pairs representing HTTP headers. It runs at startup and periodically (default: every 29 minutes, configurable via `CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS`).

### Environment variables (from `env` in settings or system environment)

All OTel configuration is via standard OpenTelemetry environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enables telemetry collection (required) | `1` |
| `OTEL_METRICS_EXPORTER` | Metrics exporter types (comma-separated) | `otlp`, `prometheus`, `console`, `none` |
| `OTEL_LOGS_EXPORTER` | Logs/events exporter types | `otlp`, `console`, `none` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Protocol for OTLP exporter | `grpc`, `http/json`, `http/protobuf` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint | `http://localhost:4317` |
| `OTEL_EXPORTER_OTLP_HEADERS` | Authentication headers for OTLP | `Authorization=Bearer token` |
| `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL` | Protocol override for metrics | `grpc`, `http/json`, `http/protobuf` |
| `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` | Endpoint override for metrics | `http://localhost:4318/v1/metrics` |
| `OTEL_EXPORTER_OTLP_LOGS_PROTOCOL` | Protocol override for logs | `grpc`, `http/json`, `http/protobuf` |
| `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` | Endpoint override for logs | `http://localhost:4318/v1/logs` |
| `OTEL_METRIC_EXPORT_INTERVAL` | Export interval in ms (default: 60000) | `5000` |
| `OTEL_LOGS_EXPORT_INTERVAL` | Logs export interval in ms (default: 5000) | `1000` |
| `OTEL_LOG_USER_PROMPTS` | Log user prompt content | `1` |
| `OTEL_LOG_TOOL_DETAILS` | Log tool parameters and input | `1` |
| `OTEL_RESOURCE_ATTRIBUTES` | Custom resource attributes | `department=eng,team.id=platform` |
| `OTEL_METRICS_INCLUDE_SESSION_ID` | Include session.id in metrics | `true` (default) |
| `OTEL_METRICS_INCLUDE_VERSION` | Include app.version in metrics | `false` (default) |
| `OTEL_METRICS_INCLUDE_ACCOUNT_UUID` | Include account IDs in metrics | `true` (default) |
| `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE` | Metrics temporality | `delta` (default), `cumulative` |
| `CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS` | Headers helper refresh interval | `900000` (ms) |

### What Claude Code exports (informational reference)

**Metrics** (via `OTEL_METRICS_EXPORTER`):
- `claude_code.session.count` — sessions started
- `claude_code.lines_of_code.count` — lines added/removed
- `claude_code.pull_request.count` — PRs created
- `claude_code.commit.count` — commits created
- `claude_code.cost.usage` — session cost (USD)
- `claude_code.token.usage` — tokens used (by type: input/output/cacheRead/cacheCreation)
- `claude_code.code_edit_tool.decision` — code edit tool permission decisions
- `claude_code.active_time.total` — active time in seconds

**Events** (via `OTEL_LOGS_EXPORTER`):
- `claude_code.user_prompt` — user prompt submitted
- `claude_code.tool_result` — tool execution completed
- `claude_code.api_request` — API request to Claude
- `claude_code.api_error` — API request failed
- `claude_code.tool_decision` — tool permission decision made

## Required models and types

### 1. `OTelConfigState`

Detection and display of the OTel configuration:

```swift
struct OTelConfigState: Codable {
    let isEnabled: Bool                          // CLAUDE_CODE_ENABLE_TELEMETRY == "1"
    let metricsExporter: String?                 // OTEL_METRICS_EXPORTER value
    let logsExporter: String?                    // OTEL_LOGS_EXPORTER value
    let otlpProtocol: String?                    // OTEL_EXPORTER_OTLP_PROTOCOL
    let otlpEndpoint: String?                    // OTEL_EXPORTER_OTLP_ENDPOINT
    let metricsProtocol: String?                 // OTEL_EXPORTER_OTLP_METRICS_PROTOCOL
    let logsProtocol: String?                    // OTEL_EXPORTER_OTLP_LOGS_PROTOCOL
    let metricsEndpoint: String?                 // Override endpoint for metrics
    let logsEndpoint: String?                    // Override endpoint for logs
    let headersHelperScript: String?             // otelHeadersHelper from settings.json
    let headersHelperDebounceMs: Int?            // CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS
    let staticHeaderKeys: [String]               // Header names only; never display secret values
    let metricsExportIntervalMs: Int?            // OTEL_METRIC_EXPORT_INTERVAL
    let logsExportIntervalMs: Int?               // OTEL_LOGS_EXPORT_INTERVAL
    let logsUserPrompts: Bool                    // OTEL_LOG_USER_PROMPTS == "1"
    let logsToolDetails: Bool                    // OTEL_LOG_TOOL_DETAILS == "1"
    let resourceAttributes: String?              // OTEL_RESOURCE_ATTRIBUTES raw value
    let includeSessionId: Bool                   // OTEL_METRICS_INCLUDE_SESSION_ID (default true)
    let includeVersion: Bool                     // OTEL_METRICS_INCLUDE_VERSION (default false)
    let includeAccountUuid: Bool                 // OTEL_METRICS_INCLUDE_ACCOUNT_UUID (default true)
    let metricsTemporalityPreference: String?    // OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE

    /// Sources: which scope(s) contributed OTel config (managed env, user env, system env)
    let configSources: [String]

    static func detect(
        from settingsDocuments: [ParsedSettingsDocument],
        systemEnv: [String: String]
    ) -> OTelConfigState {
        // 1. Check for CLAUDE_CODE_ENABLE_TELEMETRY in env settings or system env
        // 2. Extract exporter types, endpoints, and per-signal protocols
        // 3. Check for otelHeadersHelper in settings and debounce env
        // 4. Parse header names without exposing header values
        // 5. Extract cardinality control flags and temporality
        // 6. Record which sources contributed
    }
}
```

### 2. `OTelConfigIssue`

Diagnostic issues for OTel configuration:

```swift
enum OTelConfigIssue: LocalizedError {
    case telemetryNotEnabled
    case noExporterConfigured
    case endpointNotConfigured
    case headersHelperNotFound(path: String)
    case invalidResourceAttributes(details: String)

    var errorDescription: String? {
        switch self {
        case .telemetryNotEnabled:
            return "Telemetry is not enabled (CLAUDE_CODE_ENABLE_TELEMETRY not set)"
        case .noExporterConfigured:
            return "Telemetry is enabled but no exporter is configured"
        case .endpointNotConfigured:
            return "OTLP exporter configured but no endpoint specified"
        case .headersHelperNotFound(let path):
            return "otelHeadersHelper script not found: \(path)"
        case .invalidResourceAttributes(let details):
            return "Invalid OTEL_RESOURCE_ATTRIBUTES: \(details)"
        }
    }
}
```

## Detection service

### `OTelConfigDetector`

A service for detecting OTel configuration state:

```swift
@MainActor
final class OTelConfigDetector: ObservableObject {
    @Published var configState: OTelConfigState?
    @Published var configIssues: [OTelConfigIssue] = []

    /// Detect OTel configuration from resolved settings and system environment.
    func detect(
        settingsDocuments: [ParsedSettingsDocument],
        systemEnv: [String: String] = ProcessInfo.processInfo.environment
    )

    /// Validate the detected configuration for common issues.
    func validate() -> [OTelConfigIssue]
}
```

### Detection flow

1. Scan the `env` key in settings documents across all scopes (managed first)
2. Check system environment variables as fallback
3. Look for `otelHeadersHelper` in settings documents
4. Build `OTelConfigState` from all sources
5. Validate: if enabled but no exporter, if OTLP but no endpoint, if headers helper script exists on disk
6. Publish `configState` and `configIssues`

## Deliverables

### 1. Core models

- `OTelConfigState` for configuration detection and display
- `OTelConfigIssue` for diagnostics
- Reference constants for known Claude Code metric names, event names, and prompt-level correlation attributes

### 2. Configuration detection

- `OTelConfigDetector` service that reads env vars from settings + system
- `otelHeadersHelper` detection (string script path, not object)
- Validation for common misconfigurations

### 3. UI integration

- Optional "Telemetry" section in the settings view (only shown if any OTel config is detected)
- Display: enabled state, exporter types, endpoint, global/per-signal protocols, export intervals, and metrics temporality
- Show privacy-relevant flags: whether user prompts and tool details are logged
- Show cardinality control settings
- Show `otelHeadersHelper` script path if configured
- Show headers helper debounce interval if configured
- Show static OTLP header names only; never show secret header values
- If OTel is not configured at all, this section should not appear
- If partially configured (e.g., enabled but no exporter), show diagnostic warnings

### 4. Reference data

- Static list of Claude Code metric names with descriptions (for informational display)
- Static list of Claude Code event names with descriptions
- Static list of documented correlation attributes used to tie prompt-level telemetry together (for example `prompt.id`)
- This data is compiled from docs, not fetched at runtime

### 5. Fixtures

**`Fixtures/runtime/otel/full_config/input/settings.json`:**
```json
{
  "otelHeadersHelper": "/bin/generate_otel_headers.sh",
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4317",
    "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL": "http/protobuf",
    "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": "delta",
    "CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS": "900000"
  }
}
```

**`Fixtures/runtime/otel/no_config/input/settings.json`:**
```json
{
  "model": "claude-opus-4-6"
}
```

**`Fixtures/runtime/otel/partial_config/input/settings.json`:**
```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1"
  }
}
```

**`Fixtures/runtime/otel/privacy_flags/input/settings.json`:**
```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_LOG_USER_PROMPTS": "1",
    "OTEL_LOG_TOOL_DETAILS": "1",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.example.com:4317"
  }
}
```

## Tests

### Unit tests for `OTelConfigState`

- Detect full OTel configuration from settings with env vars
- Detect `otelHeadersHelper` as string script path (NOT object)
- Return `isEnabled = false` when no telemetry env var is set
- Parse exporter types correctly (comma-separated values)
- Parse per-signal protocol overrides and temporality
- Capture header names without exposing header values
- Parse cardinality control flags with correct defaults
- Handle env vars from multiple scopes (managed overrides user)

### Unit tests for validation

- Enabled but no exporter → warning
- OTLP exporter but no endpoint → warning
- Headers helper script path validation
- No config at all → not shown

### Integration tests for `OTelConfigDetector`

- Detect OTel from managed settings env
- Detect OTel from user settings env
- Detect from system environment as fallback
- Combine settings and system env correctly
- Collect validation issues without throwing

## Acceptance criteria

- [ ] `OTelConfigState` correctly detects OTel configuration from env vars in settings
- [ ] `otelHeadersHelper` is treated as a string (script path), not an object
- [ ] No HTTP requests are made to any OTel endpoint (this is detection/display only)
- [ ] No attempt to ingest or display OTel spans/metrics/events from a collector
- [ ] When OTel is not configured, the section does not appear in the UI
- [ ] When OTel is configured, the display shows exporter types, endpoint, protocol details, and privacy flags
- [ ] Secret header values are never displayed; only presence or header names are shown
- [ ] Validation catches common misconfigurations (enabled but no exporter, no endpoint)
- [ ] Known Claude Code metrics and events are listed as reference data
- [ ] Prompt-level correlation attributes are documented in the UI reference data
- [ ] App remains fully functional if OTel is not configured
- [ ] Full test suite passes
