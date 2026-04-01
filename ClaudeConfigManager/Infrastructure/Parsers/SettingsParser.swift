import Foundation

struct ParseResult<Value: Equatable & Sendable>: Equatable, Sendable {
    let value: Value?
    let issues: [SyntaxIssue]

    var hasErrors: Bool {
        issues.contains(where: { $0.severity == .error })
    }
}

struct SourceFileReference: Equatable, Sendable {
    let url: URL
    let displayPath: String

    init(url: URL) {
        self.url = url
        self.displayPath = url.path
    }
}

struct SourceRange: Equatable, Sendable {
    let startLine: Int
    let startColumn: Int
    let endLine: Int
    let endColumn: Int
}

enum IssueSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error
}

enum SyntaxIssueCode: String, Equatable, Sendable {
    case invalidJSON
    case topLevelNotObject
    case typeMismatch
    case invalidHookShape
    case invalidPermissionsShape
    case invalidEnvShape
    case invalidAttributionShape
    case invalidClaudeJsonGlobalPreferencesShape
    case invalidClaudeJsonMcpShape
    case invalidTrustStateShape
    case settingsFamilyKeyInClaudeJson
    case preservedUnsupportedKey
    case invalidFrontmatterFence
    case invalidYAMLFrontmatter
    case frontmatterTopLevelNotObject
    case missingSkillMarkdown
    case invalidMarkdownReferenceToken
}

struct SyntaxIssue: Equatable, Identifiable, Sendable {
    let id: String
    let code: SyntaxIssueCode
    let severity: IssueSeverity
    let message: String
    let sourcePath: String
    let keyPath: String?
    let range: SourceRange?

    init(
        code: SyntaxIssueCode,
        severity: IssueSeverity,
        message: String,
        sourcePath: String,
        keyPath: String? = nil,
        range: SourceRange? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.sourcePath = sourcePath
        self.keyPath = keyPath
        self.range = range
        self.id = "\(code.rawValue)-\(sourcePath)-\(keyPath ?? "root")-\(message)"
    }
}

enum JSONValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    static func from(any value: Any) -> JSONValue {
        switch value {
        case let stringValue as String:
            return .string(stringValue)
        case let boolValue as Bool:
            return .bool(boolValue)
        case let numberValue as NSNumber:
            // Bool is bridged as NSNumber, so this branch is only numeric values.
            return .number(numberValue.doubleValue)
        case let dictionary as [String: Any]:
            return .object(dictionary.mapValues { JSONValue.from(any: $0) })
        case let array as [Any]:
            return .array(array.map(JSONValue.from(any:)))
        case _ as NSNull:
            return .null
        default:
            return .null
        }
    }
}

struct ParsedSettingsDocument: Equatable, Sendable {
    let source: SourceFileReference
    let value: SettingsDocumentValue
    let rawTopLevelObject: [String: JSONValue]
    let unsupportedTopLevelKeys: [String: JSONValue]
}

struct SettingsDocumentValue: Equatable, Sendable {
    let schema: String?
    let apiKeyHelper: String?
    let autoMemoryDirectory: String?
    let cleanupPeriodDays: Int?
    let companyAnnouncements: Bool?
    let env: ParsedEnvMap?
    let attribution: ParsedAttribution?
    let includeCoAuthoredBy: Bool?
    let includeGitInstructions: Bool?
    let permissions: ParsedPermissions?
    let autoMode: Bool?
    let disableAutoMode: Bool?
    let useAutoModeDuringPlan: Bool?
    let disableDeepLinkRegistration: Bool?
    let hooks: ParsedHooks?
    let allowManagedHooksOnly: Bool?
    let allowedHTTPHookURLs: [String]?
    let httpHookAllowedEnvVars: [String]?
    let pluginSettings: [String: JSONValue]
}

struct ParsedEnvMap: Equatable, Sendable {
    let values: [String: String]
    let rawObject: [String: JSONValue]
}

struct ParsedAttribution: Equatable, Sendable {
    let includeCoAuthoredBy: Bool?
    let rawObject: [String: JSONValue]
}

struct ParsedPermissions: Equatable, Sendable {
    let allow: [String]?
    let deny: [String]?
    let mode: String?
    let rawObject: [String: JSONValue]
}

struct ParsedHooks: Equatable, Sendable {
    let events: [String: ParsedHookEvent]
    let rawObject: [String: JSONValue]
}

struct ParsedHookEvent: Equatable, Sendable {
    let matcher: String?
    let actions: [ParsedHookAction]
    let rawValue: JSONValue
}

struct ParsedHookAction: Equatable, Sendable {
    let type: String?
    let command: String?
    let url: String?
    let timeoutMs: Int?
    let rawObject: [String: JSONValue]
}

struct SettingsParser {
    private static let knownTopLevelKeys: Set<String> = [
        "$schema",
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

    func parse(data: Data, sourceURL: URL) -> ParseResult<ParsedSettingsDocument> {
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
                    message: "settings.json must contain a top-level JSON object.",
                    sourcePath: source.displayPath
                )
            )
            return ParseResult(value: nil, issues: issues)
        }

        let rawTopLevel = root.mapValues { JSONValue.from(any: $0) }

        let schema = parseString("$schema", from: root, sourcePath: source.displayPath, issues: &issues)
        let apiKeyHelper = parseString("apiKeyHelper", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoMemoryDirectory = parseString("autoMemoryDirectory", from: root, sourcePath: source.displayPath, issues: &issues)
        let cleanupPeriodDays = parseInt("cleanupPeriodDays", from: root, sourcePath: source.displayPath, issues: &issues)
        let companyAnnouncements = parseBool("companyAnnouncements", from: root, sourcePath: source.displayPath, issues: &issues)
        let includeCoAuthoredBy = parseBool("includeCoAuthoredBy", from: root, sourcePath: source.displayPath, issues: &issues)
        let includeGitInstructions = parseBool("includeGitInstructions", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoMode = parseBool("autoMode", from: root, sourcePath: source.displayPath, issues: &issues)
        let disableAutoMode = parseBool("disableAutoMode", from: root, sourcePath: source.displayPath, issues: &issues)
        let useAutoModeDuringPlan = parseBool("useAutoModeDuringPlan", from: root, sourcePath: source.displayPath, issues: &issues)
        let disableDeepLinkRegistration = parseBool("disableDeepLinkRegistration", from: root, sourcePath: source.displayPath, issues: &issues)
        let allowManagedHooksOnly = parseBool("allowManagedHooksOnly", from: root, sourcePath: source.displayPath, issues: &issues)
        let allowedHTTPHookURLs = parseStringArray("allowedHttpHookUrls", from: root, sourcePath: source.displayPath, issues: &issues)
        let httpHookAllowedEnvVars = parseStringArray("httpHookAllowedEnvVars", from: root, sourcePath: source.displayPath, issues: &issues)

        let env = parseEnv(from: root, sourcePath: source.displayPath, issues: &issues)
        let attribution = parseAttribution(from: root, sourcePath: source.displayPath, issues: &issues)
        let permissions = parsePermissions(from: root, sourcePath: source.displayPath, issues: &issues)
        let hooks = parseHooks(from: root, sourcePath: source.displayPath, issues: &issues)

        let pluginSettings = rawTopLevel.filter { isPluginRelatedKey($0.key) }

        var unsupportedTopLevelKeys: [String: JSONValue] = [:]
        for (key, value) in rawTopLevel where !Self.knownTopLevelKeys.contains(key) && !isPluginRelatedKey(key) {
            unsupportedTopLevelKeys[key] = value
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

        let value = SettingsDocumentValue(
            schema: schema,
            apiKeyHelper: apiKeyHelper,
            autoMemoryDirectory: autoMemoryDirectory,
            cleanupPeriodDays: cleanupPeriodDays,
            companyAnnouncements: companyAnnouncements,
            env: env,
            attribution: attribution,
            includeCoAuthoredBy: includeCoAuthoredBy,
            includeGitInstructions: includeGitInstructions,
            permissions: permissions,
            autoMode: autoMode,
            disableAutoMode: disableAutoMode,
            useAutoModeDuringPlan: useAutoModeDuringPlan,
            disableDeepLinkRegistration: disableDeepLinkRegistration,
            hooks: hooks,
            allowManagedHooksOnly: allowManagedHooksOnly,
            allowedHTTPHookURLs: allowedHTTPHookURLs,
            httpHookAllowedEnvVars: httpHookAllowedEnvVars,
            pluginSettings: pluginSettings
        )

        let document = ParsedSettingsDocument(
            source: source,
            value: value,
            rawTopLevelObject: rawTopLevel,
            unsupportedTopLevelKeys: unsupportedTopLevelKeys
        )

        return ParseResult(value: document, issues: issues)
    }

    func parse(jsonString: String, sourceURL: URL) -> ParseResult<ParsedSettingsDocument> {
        parse(data: Data(jsonString.utf8), sourceURL: sourceURL)
    }

    private func parseEnv(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedEnvMap? {
        guard let envValue = root["env"] else {
            return nil
        }

        guard let envObject = envValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidEnvShape,
                    severity: .error,
                    message: "'env' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "env"
                )
            )
            return nil
        }

        var values: [String: String] = [:]
        for key in envObject.keys.sorted() {
            guard let stringValue = envObject[key] as? String else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected string value at env.\(key).",
                        sourcePath: sourcePath,
                        keyPath: "env.\(key)"
                    )
                )
                continue
            }
            values[key] = stringValue
        }

        return ParsedEnvMap(values: values, rawObject: envObject.mapValues { JSONValue.from(any: $0) })
    }

    private func parseAttribution(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedAttribution? {
        guard let attributionValue = root["attribution"] else {
            return nil
        }

        guard let attributionObject = attributionValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidAttributionShape,
                    severity: .error,
                    message: "'attribution' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "attribution"
                )
            )
            return nil
        }

        var includeCoAuthoredBy: Bool?
        if let rawValue = attributionObject["includeCoAuthoredBy"] {
            guard let boolValue = rawValue as? Bool else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected bool at attribution.includeCoAuthoredBy.",
                        sourcePath: sourcePath,
                        keyPath: "attribution.includeCoAuthoredBy"
                    )
                )
                return ParsedAttribution(includeCoAuthoredBy: nil, rawObject: attributionObject.mapValues { JSONValue.from(any: $0) })
            }
            includeCoAuthoredBy = boolValue
        }

        return ParsedAttribution(includeCoAuthoredBy: includeCoAuthoredBy, rawObject: attributionObject.mapValues { JSONValue.from(any: $0) })
    }

    private func parsePermissions(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedPermissions? {
        guard let permissionsValue = root["permissions"] else {
            return nil
        }

        guard let permissionsObject = permissionsValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidPermissionsShape,
                    severity: .error,
                    message: "'permissions' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "permissions"
                )
            )
            return nil
        }

        let allow = parseStringArray(
            "allow",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        )

        let deny = parseStringArray(
            "deny",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        )

        let mode = parseString(
            "mode",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        )

        return ParsedPermissions(
            allow: allow,
            deny: deny,
            mode: mode,
            rawObject: permissionsObject.mapValues { JSONValue.from(any: $0) }
        )
    }

    private func parseHooks(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedHooks? {
        guard let hooksValue = root["hooks"] else {
            return nil
        }

        guard let hooksObject = hooksValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .invalidHookShape,
                    severity: .error,
                    message: "'hooks' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "hooks"
                )
            )
            return nil
        }

        var events: [String: ParsedHookEvent] = [:]

        for eventName in hooksObject.keys.sorted() {
            let keyPath = "hooks.\(eventName)"
            let eventValue = hooksObject[eventName]!

            if let actionsArray = eventValue as? [Any] {
                let actions = parseHookActions(actionsArray, sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
                events[eventName] = ParsedHookEvent(
                    matcher: nil,
                    actions: actions,
                    rawValue: JSONValue.from(any: eventValue)
                )
                continue
            }

            if let eventObject = eventValue as? [String: Any], let nestedActions = eventObject["hooks"] as? [Any] {
                let matcher = eventObject["matcher"] as? String
                if eventObject["matcher"] != nil && matcher == nil {
                    issues.append(
                        SyntaxIssue(
                            code: .typeMismatch,
                            severity: .error,
                            message: "Expected string at \(keyPath).matcher.",
                            sourcePath: sourcePath,
                            keyPath: "\(keyPath).matcher"
                        )
                    )
                }
                let actions = parseHookActions(
                    nestedActions,
                    sourcePath: sourcePath,
                    keyPath: "\(keyPath).hooks",
                    issues: &issues
                )
                events[eventName] = ParsedHookEvent(
                    matcher: matcher,
                    actions: actions,
                    rawValue: JSONValue.from(any: eventValue)
                )
                continue
            }

            issues.append(
                SyntaxIssue(
                    code: .invalidHookShape,
                    severity: .error,
                    message: "Hook event '\(eventName)' must be an array or object containing a 'hooks' array.",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
        }

        return ParsedHooks(
            events: events,
            rawObject: hooksObject.mapValues { JSONValue.from(any: $0) }
        )
    }

    private func parseHookActions(
        _ actionArray: [Any],
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) -> [ParsedHookAction] {
        var parsedActions: [ParsedHookAction] = []

        for (index, value) in actionArray.enumerated() {
            let itemPath = "\(keyPath)[\(index)]"
            guard let actionObject = value as? [String: Any] else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidHookShape,
                        severity: .error,
                        message: "Hook action entries must be objects.",
                        sourcePath: sourcePath,
                        keyPath: itemPath
                    )
                )
                continue
            }

            let type = parseString("type", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let command = parseString("command", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let url = parseString("url", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let timeoutMs = parseInt("timeoutMs", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)

            parsedActions.append(
                ParsedHookAction(
                    type: type,
                    command: command,
                    url: url,
                    timeoutMs: timeoutMs,
                    rawObject: actionObject.mapValues { JSONValue.from(any: $0) }
                )
            )
        }

        return parsedActions
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

    private func parseInt(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> Int? {
        guard let rawValue = object[key] else {
            return nil
        }
        guard let intValue = rawValue as? Int else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected integer at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }
        return intValue
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

    private func isPluginRelatedKey(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased == "plugins"
            || lowercased.hasPrefix("plugin")
            || lowercased.hasSuffix("plugins")
            || lowercased.contains("plugin")
    }
}
