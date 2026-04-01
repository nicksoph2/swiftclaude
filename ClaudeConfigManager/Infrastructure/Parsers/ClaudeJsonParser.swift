import Foundation

enum McpTransportType: String, Equatable, Sendable {
    case stdio
    case http
    case sse
    case plugin
    case unknown
}

enum McpServerSource: Equatable, Sendable {
    case mcpJson(path: String)
    case claudeJson
    case managed
    case plugin(id: String)
}

struct McpServerConfig: Equatable, Sendable {
    let name: String
    let transportType: McpTransportType
    let command: String?
    let args: [String]?
    let env: [String: String]?
    let cwd: String?
    let url: String?
    let headers: [String: String]?
    let pluginId: String?
    let pluginName: String?
    let source: McpServerSource
    let unknownFields: [String: JSONValue]?
}

struct ParsedClaudeJsonDocument: Equatable, Sendable {
    let source: SourceFileReference
    let value: ClaudeJsonDocumentValue
    let rawTopLevelObject: [String: JSONValue]
    let unsupportedTopLevelKeys: [String: JSONValue]
    let settingsFamilyTopLevelKeys: [String: JSONValue]
}

struct ClaudeJsonDocumentValue: Equatable, Sendable {
    let schema: String?
    let autoConnectIde: Bool?
    let autoInstallIdeExtension: Bool?
    let editorMode: String?
    let showTurnDuration: Bool?
    let terminalProgressBarEnabled: Bool?
    let teammateMode: String?
    let globalPreferences: ClaudeJsonGlobalPreferences?
    let mcpState: ParsedClaudeJsonMcpState?
    let trustState: ParsedTrustState?

    init(
        schema: String?,
        autoConnectIde: Bool? = nil,
        autoInstallIdeExtension: Bool? = nil,
        editorMode: String? = nil,
        showTurnDuration: Bool? = nil,
        terminalProgressBarEnabled: Bool? = nil,
        teammateMode: String? = nil,
        globalPreferences: ClaudeJsonGlobalPreferences?,
        mcpState: ParsedClaudeJsonMcpState?,
        trustState: ParsedTrustState?
    ) {
        self.schema = schema
        self.autoConnectIde = autoConnectIde
        self.autoInstallIdeExtension = autoInstallIdeExtension
        self.editorMode = editorMode
        self.showTurnDuration = showTurnDuration
        self.terminalProgressBarEnabled = terminalProgressBarEnabled
        self.teammateMode = teammateMode
        self.globalPreferences = globalPreferences
        self.mcpState = mcpState
        self.trustState = trustState
    }
}

struct ClaudeJsonGlobalPreferences: Equatable, Sendable {
    let defaultModel: String?
    let defaultMode: String?
    let telemetryEnabled: Bool?
    let rawObject: [String: JSONValue]
}

struct ParsedClaudeJsonMcpState: Equatable, Sendable {
    let userServers: [String: ParsedClaudeJsonMcpServerRef]
    let localServers: [String: ParsedClaudeJsonMcpServerRef]
    let rawObject: [String: JSONValue]
}

struct ParsedClaudeJsonMcpServerRef: Equatable, Sendable {
    let config: McpServerConfig
    let command: String?
    let args: [String]?
    let env: [String: String]?
    let cwd: String?
    let url: String?
    let headers: [String: String]?
    let pluginId: String?
    let pluginName: String?
    let transportType: McpTransportType
    let serverSource: McpServerSource
    let enabled: Bool?
    let source: String?
    let rawObject: [String: JSONValue]

    init(
        config: McpServerConfig,
        enabled: Bool?,
        source: String?,
        rawObject: [String: JSONValue]
    ) {
        self.config = config
        self.command = config.command
        self.args = config.args
        self.env = config.env
        self.cwd = config.cwd
        self.url = config.url
        self.headers = config.headers
        self.pluginId = config.pluginId
        self.pluginName = config.pluginName
        self.transportType = config.transportType
        self.serverSource = config.source
        self.enabled = enabled
        self.source = source
        self.rawObject = rawObject
    }
}

struct ParsedTrustState: Equatable, Sendable {
    let trustedProjectPaths: [String]
    let blockedProjectPaths: [String]
    let rawObject: [String: JSONValue]
}

struct ClaudeJsonParser {
    private static let knownTopLevelKeys: Set<String> = [
        "$schema",
        "autoConnectIde",
        "autoInstallIdeExtension",
        "editorMode",
        "globalPreferences",
        "mcp",
        "showTurnDuration",
        "terminalProgressBarEnabled",
        "teammateMode",
        "trust"
    ]

    private static let settingsJsonTopLevelKeys: Set<String> = [
        "apiKeyHelper",
        "forceLoginMethod",
        "forceLoginOrgUUID",
        "otelHeadersHelper",
        "awsAuthRefresh",
        "awsCredentialExport",
        "autoMemoryDirectory",
        "cleanupPeriodDays",
        "companyAnnouncements",
        "env",
        "attribution",
        "includeCoAuthoredBy",
        "includeGitInstructions",
        "permissions",
        "autoMode",
        "disableAutoMode",
        "useAutoModeDuringPlan",
        "disableDeepLinkRegistration",
        "hooks",
        "allowManagedHooksOnly",
        "allowedHttpHookUrls",
        "httpHookAllowedEnvVars",
        "plugins",
        "enabledPlugins",
        "disabledPlugins"
    ]

    func parse(data: Data, sourceURL: URL) -> ParseResult<ParsedClaudeJsonDocument> {
        let source = SourceFileReference(url: sourceURL)
        var issues: [SyntaxIssue] = []

        let rootAny: Any
        do {
            rootAny = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            issues.append(
                SyntaxIssue(
                    code: .invalidJSON,
                    severity: .error,
                    message: "Invalid JSON syntax: \(error.localizedDescription)",
                    sourcePath: source.displayPath
                )
            )
            return ParseResult(value: nil, issues: issues)
        }

        guard let root = rootAny as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .topLevelNotObject,
                    severity: .error,
                    message: "~/.claude.json must contain a top-level JSON object.",
                    sourcePath: source.displayPath
                )
            )
            return ParseResult(value: nil, issues: issues)
        }

        let rawTopLevel = root.mapValues { JSONValue.from(any: $0) }

        let schema = parseString("$schema", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoConnectIde = parseBool("autoConnectIde", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoInstallIdeExtension = parseBool("autoInstallIdeExtension", from: root, sourcePath: source.displayPath, issues: &issues)
        let editorMode = parseEnumString(
            "editorMode",
            allowedValues: ["normal", "vim"],
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let globalPreferences = parseGlobalPreferences(from: root, sourcePath: source.displayPath, issues: &issues)
        let mcpState = parseMcpState(from: root, sourceURL: sourceURL, sourcePath: source.displayPath, issues: &issues)
        let showTurnDuration = parseBool("showTurnDuration", from: root, sourcePath: source.displayPath, issues: &issues)
        let terminalProgressBarEnabled = parseBool("terminalProgressBarEnabled", from: root, sourcePath: source.displayPath, issues: &issues)
        let teammateMode = parseEnumString(
            "teammateMode",
            allowedValues: ["auto", "in-process", "tmux"],
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let trustState = parseTrustState(from: root, sourcePath: source.displayPath, issues: &issues)

        var unsupportedTopLevelKeys: [String: JSONValue] = [:]
        var settingsFamilyTopLevelKeys: [String: JSONValue] = [:]

        for (key, value) in rawTopLevel where !Self.knownTopLevelKeys.contains(key) {
            unsupportedTopLevelKeys[key] = value

            if Self.settingsJsonTopLevelKeys.contains(key) {
                settingsFamilyTopLevelKeys[key] = value
                issues.append(
                    SyntaxIssue(
                        code: .settingsFamilyKeyInClaudeJson,
                        severity: .warning,
                        message: "Key '\(key)' looks like a settings.json field and was preserved as unsupported in ~/.claude.json.",
                        sourcePath: source.displayPath,
                        keyPath: key
                    )
                )
                continue
            }

            issues.append(
                SyntaxIssue(
                    code: .preservedUnsupportedKey,
                    severity: .info,
                    message: "Unsupported top-level key '\(key)' was preserved for forward compatibility.",
                    sourcePath: source.displayPath,
                    keyPath: key
                )
            )
        }

        let value = ClaudeJsonDocumentValue(
            schema: schema,
            autoConnectIde: autoConnectIde,
            autoInstallIdeExtension: autoInstallIdeExtension,
            editorMode: editorMode,
            showTurnDuration: showTurnDuration,
            terminalProgressBarEnabled: terminalProgressBarEnabled,
            teammateMode: teammateMode,
            globalPreferences: globalPreferences,
            mcpState: mcpState,
            trustState: trustState
        )

        let document = ParsedClaudeJsonDocument(
            source: source,
            value: value,
            rawTopLevelObject: rawTopLevel,
            unsupportedTopLevelKeys: unsupportedTopLevelKeys,
            settingsFamilyTopLevelKeys: settingsFamilyTopLevelKeys
        )

        // Run lightweight validation if no parse errors occurred
        if !issues.contains(where: { $0.severity == .error }) {
            let validator = ClaudeJsonValidator()
            let validationIssues = validator.validate(document)
            issues.append(contentsOf: validationIssues)
        }

        return ParseResult(value: document, issues: issues)
    }

    func parse(jsonString: String, sourceURL: URL) -> ParseResult<ParsedClaudeJsonDocument> {
        parse(data: Data(jsonString.utf8), sourceURL: sourceURL)
    }

    private func parseGlobalPreferences(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ClaudeJsonGlobalPreferences? {
        guard let value = root["globalPreferences"] else {
            return nil
        }

        guard let object = value as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidClaudeJsonGlobalPreferencesShape,
                    severity: .error,
                    message: "'globalPreferences' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "globalPreferences"
                )
            )
            return nil
        }

        let defaultModel = parseString(
            "defaultModel",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: "globalPreferences",
            issues: &issues
        )

        let defaultMode = parseString(
            "defaultMode",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: "globalPreferences",
            issues: &issues
        )

        let telemetryEnabled = parseBool(
            "telemetryEnabled",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: "globalPreferences",
            issues: &issues
        )

        return ClaudeJsonGlobalPreferences(
            defaultModel: defaultModel,
            defaultMode: defaultMode,
            telemetryEnabled: telemetryEnabled,
            rawObject: object.mapValues { JSONValue.from(any: $0) }
        )
    }

    private func parseMcpState(
        from root: [String: Any],
        sourceURL: URL,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedClaudeJsonMcpState? {
        guard let value = root["mcp"] else {
            return nil
        }

        guard let object = value as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidClaudeJsonMcpShape,
                    severity: .error,
                    message: "'mcp' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "mcp"
                )
            )
            return nil
        }

        let userServers = parseMcpServerCollection(
            key: "user",
            from: object,
            sourceURL: sourceURL,
            sourcePath: sourcePath,
            parentPath: "mcp",
            issues: &issues
        ) ?? [:]

        let localServers = parseMcpServerCollection(
            key: "local",
            from: object,
            sourceURL: sourceURL,
            sourcePath: sourcePath,
            parentPath: "mcp",
            issues: &issues
        ) ?? [:]

        return ParsedClaudeJsonMcpState(
            userServers: userServers,
            localServers: localServers,
            rawObject: object.mapValues { JSONValue.from(any: $0) }
        )
    }

    private func parseMcpServerCollection(
        key: String,
        from object: [String: Any],
        sourceURL: URL,
        sourcePath: String,
        parentPath: String,
        issues: inout [SyntaxIssue]
    ) -> [String: ParsedClaudeJsonMcpServerRef]? {
        guard let value = object[key] else {
            return nil
        }

        let collectionPath = "\(parentPath).\(key)"
        guard let collectionObject = value as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidClaudeJsonMcpShape,
                    severity: .error,
                    message: "'\(collectionPath)' must be a JSON object keyed by server id.",
                    sourcePath: sourcePath,
                    keyPath: collectionPath
                )
            )
            return nil
        }

        var servers: [String: ParsedClaudeJsonMcpServerRef] = [:]

        for serverID in collectionObject.keys.sorted() {
            let keyPath = "\(collectionPath).\(serverID)"
            guard let serverObject = collectionObject[serverID] as? [String: Any] else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidClaudeJsonMcpShape,
                        severity: .error,
                        message: "Server '\(serverID)' at \(collectionPath) must be a JSON object.",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                continue
            }

            let command = parseString("command", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let args = parseStringArray("args", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let env = parseStringMap("env", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let cwd = parseString("cwd", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let url = parseString("url", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let headers = parseStringMap("headers", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let pluginId = parseString("pluginId", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let pluginName = parseString("pluginName", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let transport = parseString("transport", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let enabled = parseBool("enabled", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let source = parseString("source", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let rawObject = serverObject.mapValues { JSONValue.from(any: $0) }

            let transportType = detectTransportType(
                serverObject: serverObject,
                command: command,
                url: url,
                pluginId: pluginId,
                transport: transport,
                sourcePath: sourcePath,
                keyPath: keyPath,
                issues: &issues
            )
            let serverSource = inferMcpServerSource(
                sourceURL: sourceURL,
                transportType: transportType,
                pluginId: pluginId
            )
            let config = McpServerConfig(
                name: serverID,
                transportType: transportType,
                command: command,
                args: args,
                env: env,
                cwd: cwd,
                url: url,
                headers: headers,
                pluginId: pluginId,
                pluginName: pluginName,
                source: serverSource,
                unknownFields: rawObject.filter { !Self.knownMcpServerKeys.contains($0.key) }
            )

            servers[serverID] = ParsedClaudeJsonMcpServerRef(config: config, enabled: enabled, source: source, rawObject: rawObject)
        }

        return servers
    }

    private static let knownMcpServerKeys: Set<String> = [
        "args",
        "command",
        "cwd",
        "enabled",
        "env",
        "headers",
        "pluginId",
        "pluginName",
        "source",
        "transport",
        "url"
    ]

    private func detectTransportType(
        serverObject: [String: Any],
        command: String?,
        url: String?,
        pluginId: String?,
        transport: String?,
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) -> McpTransportType {
        let hasCommandKey = serverObject.keys.contains("command")
        let hasURLKey = serverObject.keys.contains("url")
        let hasPluginKey = serverObject.keys.contains("pluginId")

        if hasPluginKey, let pluginId, !pluginId.isEmpty {
            return .plugin
        }

        if hasCommandKey && hasURLKey {
            issues.append(
                SyntaxIssue(
                    code: .ambiguousMcpTransport,
                    severity: .warning,
                    message: "MCP server defines both command and url transport fields; defaulting to stdio.",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return .stdio
        }

        if hasCommandKey {
            return .stdio
        }

        if hasURLKey {
            if transport?.caseInsensitiveCompare("sse") == .orderedSame {
                issues.append(
                    SyntaxIssue(
                        code: .deprecatedMcpTransport,
                        severity: .info,
                        message: "SSE MCP transport is deprecated; prefer streamable HTTP.",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                return .sse
            }

            return .http
        }

        if hasPluginKey {
            return .unknown
        }

        issues.append(
            SyntaxIssue(
                code: .missingMcpTransport,
                severity: .warning,
                message: "MCP server must define a supported transport.",
                sourcePath: sourcePath,
                keyPath: keyPath
            )
        )
        return .unknown
    }

    private func inferMcpServerSource(
        sourceURL: URL,
        transportType: McpTransportType,
        pluginId: String?
    ) -> McpServerSource {
        if transportType == .plugin, let pluginId, !pluginId.isEmpty {
            return .plugin(id: pluginId)
        }

        switch sourceURL.lastPathComponent {
        case ".claude.json":
            return .claudeJson
        case ".mcp.json":
            return .mcpJson(path: sourceURL.path)
        case "managed-mcp.json":
            return .managed
        default:
            return .claudeJson
        }
    }

    private func parseTrustState(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedTrustState? {
        guard let value = root["trust"] else {
            return nil
        }

        guard let object = value as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidTrustStateShape,
                    severity: .error,
                    message: "'trust' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "trust"
                )
            )
            return nil
        }

        let trustedProjectPaths = parseStringArray(
            "trustedProjectPaths",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: "trust",
            issues: &issues
        ) ?? []

        let blockedProjectPaths = parseStringArray(
            "blockedProjectPaths",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: "trust",
            issues: &issues
        ) ?? []

        return ParsedTrustState(
            trustedProjectPaths: trustedProjectPaths,
            blockedProjectPaths: blockedProjectPaths,
            rawObject: object.mapValues { JSONValue.from(any: $0) }
        )
    }

    private func parseStringMap(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String,
        issues: inout [SyntaxIssue]
    ) -> [String: String]? {
        guard let rawValue = object[key] else {
            return nil
        }

        let keyPath = "\(keyPathPrefix).\(key)"
        guard let map = rawValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected object at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        var output: [String: String] = [:]
        for mapKey in map.keys.sorted() {
            guard let stringValue = map[mapKey] as? String else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected string value at \(keyPath).\(mapKey).",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).\(mapKey)"
                    )
                )
                continue
            }
            output[mapKey] = stringValue
        }

        return output
    }

    private func parseString(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> String? {
        guard let rawValue = object[key] else {
            return nil
        }

        guard let stringValue = rawValue as? String else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected string at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return stringValue
    }

    private func parseBool(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> Bool? {
        guard let rawValue = object[key] else {
            return nil
        }

        guard let boolValue = rawValue as? Bool else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected bool at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return boolValue
    }

    private func parseStringArray(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> [String]? {
        guard let rawValue = object[key] else {
            return nil
        }

        guard let anyArray = rawValue as? [Any] else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected array at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        var output: [String] = []
        for (index, item) in anyArray.enumerated() {
            guard let itemString = item as? String else {
                let keyPath = "\(buildKeyPath(prefix: keyPathPrefix, key: key))[\(index)]"
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected string entry at \(keyPath).",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                continue
            }
            output.append(itemString)
        }

        return output
    }

    private func parseEnumString(
        _ key: String,
        allowedValues: Set<String>,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> String? {
        guard let stringValue = parseString(
            key,
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: keyPathPrefix,
            issues: &issues
        ) else {
            return nil
        }

        guard allowedValues.contains(stringValue) else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            let supportedValues = allowedValues.sorted().joined(separator: ", ")
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Unsupported value '\(stringValue)' at \(keyPath). Expected one of: \(supportedValues).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return stringValue
    }

    private func buildKeyPath(prefix: String?, key: String) -> String {
        guard let prefix, !prefix.isEmpty else {
            return key
        }
        return "\(prefix).\(key)"
    }
}
