import Foundation

struct ParsedClaudeJsonDocument: Equatable, Sendable {
    let source: SourceFileReference
    let value: ClaudeJsonDocumentValue
    let rawTopLevelObject: [String: JSONValue]
    let unsupportedTopLevelKeys: [String: JSONValue]
    let settingsFamilyTopLevelKeys: [String: JSONValue]
}

struct ClaudeJsonDocumentValue: Equatable, Sendable {
    let schema: String?
    let globalPreferences: ClaudeJsonGlobalPreferences?
    let mcpState: ParsedClaudeJsonMcpState?
    let trustState: ParsedTrustState?
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
    let command: String?
    let args: [String]?
    let env: [String: String]?
    let url: String?
    let headers: [String: String]?
    let enabled: Bool?
    let source: String?
    let rawObject: [String: JSONValue]
}

struct ParsedTrustState: Equatable, Sendable {
    let trustedProjectPaths: [String]
    let blockedProjectPaths: [String]
    let rawObject: [String: JSONValue]
}

struct ClaudeJsonParser {
    private static let knownTopLevelKeys: Set<String> = [
        "$schema",
        "globalPreferences",
        "mcp",
        "trust"
    ]

    private static let settingsJsonTopLevelKeys: Set<String> = [
        "apiKeyHelper",
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
        let globalPreferences = parseGlobalPreferences(from: root, sourcePath: source.displayPath, issues: &issues)
        let mcpState = parseMcpState(from: root, sourcePath: source.displayPath, issues: &issues)
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
            sourcePath: sourcePath,
            parentPath: "mcp",
            issues: &issues
        ) ?? [:]

        let localServers = parseMcpServerCollection(
            key: "local",
            from: object,
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
            let url = parseString("url", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let headers = parseStringMap("headers", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let enabled = parseBool("enabled", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let source = parseString("source", from: serverObject, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)

            servers[serverID] = ParsedClaudeJsonMcpServerRef(
                command: command,
                args: args,
                env: env,
                url: url,
                headers: headers,
                enabled: enabled,
                source: source,
                rawObject: serverObject.mapValues { JSONValue.from(any: $0) }
            )
        }

        return servers
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

    private func buildKeyPath(prefix: String?, key: String) -> String {
        guard let prefix, !prefix.isEmpty else {
            return key
        }
        return "\(prefix).\(key)"
    }
}
