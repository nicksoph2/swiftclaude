import Foundation

// MARK: - OTel Configuration Detector

/// Detects and validates OpenTelemetry configuration from parsed settings and system environment.
/// This is read-only detection — no HTTP requests are made to any OTel endpoint.
@MainActor
final class OTelConfigDetector: ObservableObject {
    @Published var configState: OTelConfigState?
    @Published var configIssues: [OTelConfigIssue] = []

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Detect OTel configuration from resolved settings and system environment.
    func detect(
        settingsDocuments: [ParsedSettingsDocument],
        systemEnv: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let state = OTelConfigState.detect(
            from: settingsDocuments,
            systemEnv: systemEnv
        )
        configState = state
        configIssues = validate(state: state)
    }

    /// Validate the detected configuration for common issues.
    func validate(state: OTelConfigState) -> [OTelConfigIssue] {
        var issues: [OTelConfigIssue] = []

        if !state.isEnabled {
            issues.append(.telemetryNotEnabled)
            return issues
        }

        let hasMetricsExporter = state.metricsExporter != nil && state.metricsExporter != "none"
        let hasLogsExporter = state.logsExporter != nil && state.logsExporter != "none"
        if !hasMetricsExporter && !hasLogsExporter {
            issues.append(.noExporterConfigured)
        }

        let metricsIsOtlp = state.metricsExporter?.contains("otlp") == true
        let logsIsOtlp = state.logsExporter?.contains("otlp") == true
        if (metricsIsOtlp || logsIsOtlp) &&
           state.otlpEndpoint == nil && state.metricsEndpoint == nil && state.logsEndpoint == nil {
            issues.append(.endpointNotConfigured)
        }

        if let scriptPath = state.headersHelperScript, !scriptPath.isEmpty {
            let expandedPath = NSString(string: scriptPath).expandingTildeInPath
            if !fileManager.fileExists(atPath: expandedPath) {
                issues.append(.headersHelperNotFound(path: scriptPath))
            }
        }

        if let attrs = state.resourceAttributes, !attrs.isEmpty {
            let pairs = attrs.split(separator: ",")
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count != 2 || parts[0].trimmingCharacters(in: .whitespaces).isEmpty {
                    issues.append(.invalidResourceAttributes(
                        details: "Expected key=value pairs separated by commas, found: \(pair)"
                    ))
                    break
                }
            }
        }

        return issues
    }
}

// MARK: - OTelConfigState Detection

extension OTelConfigState {
    /// Detect OTel configuration from settings documents and system environment.
    /// Settings documents are checked in order (managed first), with system env as fallback.
    static func detect(
        from settingsDocuments: [ParsedSettingsDocument],
        systemEnv: [String: String]
    ) -> OTelConfigState {
        var configSources: [String] = []

        // Build a merged env map from all settings documents.
        // Earlier documents (managed) take precedence for the same key.
        var mergedSettingsEnv: [String: String] = [:]
        var settingsEnvSources: [String: String] = [:]

        for doc in settingsDocuments {
            if let envMap = doc.value.env {
                for (key, value) in envMap.values {
                    if mergedSettingsEnv[key] == nil {
                        mergedSettingsEnv[key] = value
                        settingsEnvSources[key] = doc.source.displayPath
                    }
                }
            }
        }

        // Helper to look up an env var: settings env first, then system env
        func envValue(_ key: String) -> String? {
            if let val = mergedSettingsEnv[key] {
                return val
            }
            return systemEnv[key]
        }

        func envSource(_ key: String) -> String? {
            if mergedSettingsEnv[key] != nil {
                return settingsEnvSources[key] ?? "settings env"
            }
            if systemEnv[key] != nil {
                return "system environment"
            }
            return nil
        }

        // Track which sources contributed
        var sourcesSet = Set<String>()

        func recordSource(for key: String) {
            if let src = envSource(key) {
                sourcesSet.insert(src)
            }
        }

        // Detect enabled state
        let enableTelemetry = envValue("CLAUDE_CODE_ENABLE_TELEMETRY")
        let isEnabled = enableTelemetry == "1"
        if enableTelemetry != nil { recordSource(for: "CLAUDE_CODE_ENABLE_TELEMETRY") }

        // Exporter types
        let metricsExporter = envValue("OTEL_METRICS_EXPORTER")
        if metricsExporter != nil { recordSource(for: "OTEL_METRICS_EXPORTER") }

        let logsExporter = envValue("OTEL_LOGS_EXPORTER")
        if logsExporter != nil { recordSource(for: "OTEL_LOGS_EXPORTER") }

        // OTLP protocol and endpoints
        let otlpProtocol = envValue("OTEL_EXPORTER_OTLP_PROTOCOL")
        if otlpProtocol != nil { recordSource(for: "OTEL_EXPORTER_OTLP_PROTOCOL") }

        let otlpEndpoint = envValue("OTEL_EXPORTER_OTLP_ENDPOINT")
        if otlpEndpoint != nil { recordSource(for: "OTEL_EXPORTER_OTLP_ENDPOINT") }

        let metricsProtocol = envValue("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL")
        if metricsProtocol != nil { recordSource(for: "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL") }

        let logsProtocol = envValue("OTEL_EXPORTER_OTLP_LOGS_PROTOCOL")
        if logsProtocol != nil { recordSource(for: "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL") }

        let metricsEndpoint = envValue("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")
        if metricsEndpoint != nil { recordSource(for: "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT") }

        let logsEndpoint = envValue("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
        if logsEndpoint != nil { recordSource(for: "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT") }

        // Headers helper from settings.json (NOT env)
        var headersHelperScript: String? = nil
        for doc in settingsDocuments {
            if let helper = doc.value.otelHeadersHelper {
                headersHelperScript = helper
                sourcesSet.insert(doc.source.displayPath)
                break
            }
        }

        // Headers helper debounce from env
        let debounceStr = envValue("CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS")
        let headersHelperDebounceMs = debounceStr.flatMap { Int($0) }
        if debounceStr != nil { recordSource(for: "CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS") }

        // Static header keys (extract key names only, never values)
        var staticHeaderKeys: [String] = []
        if let headersRaw = envValue("OTEL_EXPORTER_OTLP_HEADERS") {
            recordSource(for: "OTEL_EXPORTER_OTLP_HEADERS")
            let pairs = headersRaw.split(separator: ",")
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if let keyPart = parts.first {
                    let trimmed = keyPart.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        staticHeaderKeys.append(trimmed)
                    }
                }
            }
        }

        // Export intervals
        let metricsIntervalStr = envValue("OTEL_METRIC_EXPORT_INTERVAL")
        let metricsExportIntervalMs = metricsIntervalStr.flatMap { Int($0) }
        if metricsIntervalStr != nil { recordSource(for: "OTEL_METRIC_EXPORT_INTERVAL") }

        let logsIntervalStr = envValue("OTEL_LOGS_EXPORT_INTERVAL")
        let logsExportIntervalMs = logsIntervalStr.flatMap { Int($0) }
        if logsIntervalStr != nil { recordSource(for: "OTEL_LOGS_EXPORT_INTERVAL") }

        // Privacy flags
        let logsUserPrompts = envValue("OTEL_LOG_USER_PROMPTS") == "1"
        if envValue("OTEL_LOG_USER_PROMPTS") != nil { recordSource(for: "OTEL_LOG_USER_PROMPTS") }

        let logsToolDetails = envValue("OTEL_LOG_TOOL_DETAILS") == "1"
        if envValue("OTEL_LOG_TOOL_DETAILS") != nil { recordSource(for: "OTEL_LOG_TOOL_DETAILS") }

        // Resource attributes
        let resourceAttributes = envValue("OTEL_RESOURCE_ATTRIBUTES")
        if resourceAttributes != nil { recordSource(for: "OTEL_RESOURCE_ATTRIBUTES") }

        // Cardinality control flags (with defaults)
        let sessionIdStr = envValue("OTEL_METRICS_INCLUDE_SESSION_ID")
        let includeSessionId = sessionIdStr.map { $0.lowercased() != "false" } ?? true

        let versionStr = envValue("OTEL_METRICS_INCLUDE_VERSION")
        let includeVersion = versionStr.map { $0.lowercased() == "true" } ?? false

        let accountStr = envValue("OTEL_METRICS_INCLUDE_ACCOUNT_UUID")
        let includeAccountUuid = accountStr.map { $0.lowercased() != "false" } ?? true

        // Temporality
        let metricsTemporality = envValue("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE")
        if metricsTemporality != nil { recordSource(for: "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE") }

        configSources = Array(sourcesSet).sorted()

        return OTelConfigState(
            isEnabled: isEnabled,
            metricsExporter: metricsExporter,
            logsExporter: logsExporter,
            otlpProtocol: otlpProtocol,
            otlpEndpoint: otlpEndpoint,
            metricsProtocol: metricsProtocol,
            logsProtocol: logsProtocol,
            metricsEndpoint: metricsEndpoint,
            logsEndpoint: logsEndpoint,
            headersHelperScript: headersHelperScript,
            headersHelperDebounceMs: headersHelperDebounceMs,
            staticHeaderKeys: staticHeaderKeys,
            metricsExportIntervalMs: metricsExportIntervalMs,
            logsExportIntervalMs: logsExportIntervalMs,
            logsUserPrompts: logsUserPrompts,
            logsToolDetails: logsToolDetails,
            resourceAttributes: resourceAttributes,
            includeSessionId: includeSessionId,
            includeVersion: includeVersion,
            includeAccountUuid: includeAccountUuid,
            metricsTemporalityPreference: metricsTemporality,
            configSources: configSources
        )
    }
}
