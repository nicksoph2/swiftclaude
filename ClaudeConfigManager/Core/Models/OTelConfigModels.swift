import Foundation

// MARK: - OTel Configuration State

/// Represents the detected OpenTelemetry configuration for Claude Code.
/// This is a read-only detection model — the app never queries an OTel collector.
struct OTelConfigState: Equatable, Sendable {
    /// Whether telemetry collection is enabled (CLAUDE_CODE_ENABLE_TELEMETRY == "1")
    let isEnabled: Bool

    /// OTEL_METRICS_EXPORTER value (e.g. "otlp", "prometheus", "console", "none")
    let metricsExporter: String?

    /// OTEL_LOGS_EXPORTER value (e.g. "otlp", "console", "none")
    let logsExporter: String?

    /// OTEL_EXPORTER_OTLP_PROTOCOL (e.g. "grpc", "http/json", "http/protobuf")
    let otlpProtocol: String?

    /// OTEL_EXPORTER_OTLP_ENDPOINT (e.g. "http://localhost:4317")
    let otlpEndpoint: String?

    /// OTEL_EXPORTER_OTLP_METRICS_PROTOCOL override
    let metricsProtocol: String?

    /// OTEL_EXPORTER_OTLP_LOGS_PROTOCOL override
    let logsProtocol: String?

    /// OTEL_EXPORTER_OTLP_METRICS_ENDPOINT override
    let metricsEndpoint: String?

    /// OTEL_EXPORTER_OTLP_LOGS_ENDPOINT override
    let logsEndpoint: String?

    /// otelHeadersHelper from settings.json — script path string
    let headersHelperScript: String?

    /// CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS
    let headersHelperDebounceMs: Int?

    /// Header key names only from OTEL_EXPORTER_OTLP_HEADERS; never expose secret values
    let staticHeaderKeys: [String]

    /// OTEL_METRIC_EXPORT_INTERVAL in ms
    let metricsExportIntervalMs: Int?

    /// OTEL_LOGS_EXPORT_INTERVAL in ms
    let logsExportIntervalMs: Int?

    /// OTEL_LOG_USER_PROMPTS == "1"
    let logsUserPrompts: Bool

    /// OTEL_LOG_TOOL_DETAILS == "1"
    let logsToolDetails: Bool

    /// OTEL_RESOURCE_ATTRIBUTES raw value
    let resourceAttributes: String?

    /// OTEL_METRICS_INCLUDE_SESSION_ID (default true)
    let includeSessionId: Bool

    /// OTEL_METRICS_INCLUDE_VERSION (default false)
    let includeVersion: Bool

    /// OTEL_METRICS_INCLUDE_ACCOUNT_UUID (default true)
    let includeAccountUuid: Bool

    /// OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE
    let metricsTemporalityPreference: String?

    /// Which scopes contributed OTel configuration (e.g. "managed env", "user env", "system env")
    let configSources: [String]

    /// Whether any OTel-related configuration was detected at all
    var hasAnyConfig: Bool {
        isEnabled || metricsExporter != nil || logsExporter != nil ||
        otlpEndpoint != nil || headersHelperScript != nil
    }
}

// MARK: - OTel Configuration Issues

/// Diagnostic issues for OTel configuration validation.
enum OTelConfigIssue: Equatable, Sendable {
    case telemetryNotEnabled
    case noExporterConfigured
    case endpointNotConfigured
    case headersHelperNotFound(path: String)
    case invalidResourceAttributes(details: String)

    var severity: IssueSeverity {
        switch self {
        case .telemetryNotEnabled:
            return .info
        case .noExporterConfigured, .endpointNotConfigured:
            return .warning
        case .headersHelperNotFound:
            return .warning
        case .invalidResourceAttributes:
            return .warning
        }
    }

    var message: String {
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

// MARK: - Reference Data: Known Claude Code Metrics

/// Static reference list of metrics that Claude Code exports via OTel.
struct OTelMetricReference: Equatable, Sendable, Identifiable {
    let name: String
    let description: String
    var id: String { name }
}

/// Static reference list of events that Claude Code exports via OTel.
struct OTelEventReference: Equatable, Sendable, Identifiable {
    let name: String
    let description: String
    var id: String { name }
}

/// Static reference list of correlation attributes used by Claude Code telemetry.
struct OTelCorrelationAttribute: Equatable, Sendable, Identifiable {
    let name: String
    let description: String
    var id: String { name }
}

// MARK: - Reference Data Constants

enum OTelReferenceData {
    static let metrics: [OTelMetricReference] = [
        OTelMetricReference(name: "claude_code.session.count", description: "Number of sessions started"),
        OTelMetricReference(name: "claude_code.lines_of_code.count", description: "Lines of code added or removed"),
        OTelMetricReference(name: "claude_code.pull_request.count", description: "Pull requests created"),
        OTelMetricReference(name: "claude_code.commit.count", description: "Commits created"),
        OTelMetricReference(name: "claude_code.cost.usage", description: "Session cost in USD"),
        OTelMetricReference(name: "claude_code.token.usage", description: "Tokens used (by type: input, output, cacheRead, cacheCreation)"),
        OTelMetricReference(name: "claude_code.code_edit_tool.decision", description: "Code edit tool permission decisions"),
        OTelMetricReference(name: "claude_code.active_time.total", description: "Active time in seconds"),
    ]

    static let events: [OTelEventReference] = [
        OTelEventReference(name: "claude_code.user_prompt", description: "User prompt submitted"),
        OTelEventReference(name: "claude_code.tool_result", description: "Tool execution completed"),
        OTelEventReference(name: "claude_code.api_request", description: "API request to Claude"),
        OTelEventReference(name: "claude_code.api_error", description: "API request failed"),
        OTelEventReference(name: "claude_code.tool_decision", description: "Tool permission decision made"),
    ]

    static let correlationAttributes: [OTelCorrelationAttribute] = [
        OTelCorrelationAttribute(name: "session.id", description: "Unique identifier for the Claude Code session"),
        OTelCorrelationAttribute(name: "prompt.id", description: "Identifier linking events within a single prompt turn"),
        OTelCorrelationAttribute(name: "app.version", description: "Claude Code application version"),
        OTelCorrelationAttribute(name: "account.uuid", description: "Anthropic account identifier"),
    ]
}
