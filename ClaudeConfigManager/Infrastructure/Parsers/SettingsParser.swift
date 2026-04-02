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
    case ambiguousMcpTransport
    case missingMcpTransport
    case deprecatedMcpTransport
    case invalidMcpRestrictionRule
    case managedOnlySettingInNonManagedScope
    case invalidHookShape
    case preservedUnknownHookEvent
    case invalidPermissionsShape
    case invalidEnvShape
    case invalidAttributionShape
    case invalidClaudeJsonGlobalPreferencesShape
    case invalidClaudeJsonMcpShape
    case invalidTrustStateShape
    case settingsFamilyKeyInClaudeJson
    case claudeJsonOnlyKeyInSettings
    case preservedUnsupportedKey
    case invalidFrontmatterFence
    case invalidYAMLFrontmatter
    case frontmatterTopLevelNotObject
    case missingSkillMarkdown
    case invalidMarkdownReferenceToken
    case preservedUnknownValue
    case unknownKey
    case deprecatedKey
    case invalidValue
    case invalidFieldType
    case invalidEnumValue
    case scopeRestrictionViolated
    case mutuallyExclusiveKeys
    case mcpCommandNotFound
    case mcpCommandNotExecutable
    case mcpInvalidUrl
    case mcpMissingRequiredField
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
        case let numberValue as NSNumber:
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return .bool(numberValue.boolValue)
            }
            return .number(numberValue.doubleValue)
        case let boolValue as Bool:
            return .bool(boolValue)
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

extension JSONValue {
    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    var stringArrayValue: [String]? {
        guard case let .array(values) = self else { return nil }
        var strings: [String] = []
        strings.reserveCapacity(values.count)
        for value in values {
            guard case let .string(string) = value else { return nil }
            strings.append(string)
        }
        return strings
    }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case let .number(value) = self else { return nil }
        guard value.rounded() == value else { return nil }
        return Int(value)
    }

    fileprivate var foundationValue: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues(\.foundationValue)
        case .array(let value):
            return value.map(\.foundationValue)
        case .null:
            return NSNull()
        }
    }

    var prettyPrintedString: String? {
        guard JSONSerialization.isValidJSONObject(foundationValue) else {
            return nil
        }

        guard let data = try? JSONSerialization.data(withJSONObject: foundationValue, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    var prettyPrintedJSONString: String? {
        JSONValue.object(self).prettyPrintedString
    }
}

struct ParsedSettingsDocument: Equatable, Sendable {
    let source: SourceFileReference
    let value: SettingsDocumentValue
    let rawTopLevelObject: [String: JSONValue]
    let unsupportedTopLevelKeys: [String: JSONValue]
}

struct ParsedPluginMarketplace: Equatable, Sendable {
    let id: String?
    let source: ParsedPluginMarketplaceSource?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let id {
            object["id"] = .string(id)
        }
        if let source {
            object["source"] = .object(source.rawObject)
        }
        return object
    }
}

enum ParsedPluginMarketplaceSource: Equatable, Sendable {
    case github(ParsedGitHubMarketplaceSource)
    case git(ParsedGitMarketplaceSource)
    case url(ParsedURLMarketplaceSource)
    case npm(ParsedNpmMarketplaceSource)
    case file(ParsedFileMarketplaceSource)
    case directory(ParsedDirectoryMarketplaceSource)
    case hostPattern(ParsedHostPatternMarketplaceSource)
    case inline(ParsedInlineMarketplaceSource)
    case unknown(type: String?, rawObject: [String: JSONValue])

    var rawObject: [String: JSONValue] {
        switch self {
        case .github(let source):
            return source.rawObject
        case .git(let source):
            return source.rawObject
        case .url(let source):
            return source.rawObject
        case .npm(let source):
            return source.rawObject
        case .file(let source):
            return source.rawObject
        case .directory(let source):
            return source.rawObject
        case .hostPattern(let source):
            return source.rawObject
        case .inline(let source):
            return source.rawObject
        case .unknown(_, let rawObject):
            return rawObject
        }
    }
}

struct ParsedGitHubMarketplaceSource: Equatable, Sendable {
    let repo: String?
    let ref: String?
    let subpath: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("github")
        if let repo {
            object["repo"] = .string(repo)
        }
        if let ref {
            object["ref"] = .string(ref)
        }
        if let subpath {
            object["subpath"] = .string(subpath)
        }
        return object
    }
}

struct ParsedGitMarketplaceSource: Equatable, Sendable {
    let url: String?
    let ref: String?
    let subpath: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("git")
        if let url {
            object["url"] = .string(url)
        }
        if let ref {
            object["ref"] = .string(ref)
        }
        if let subpath {
            object["subpath"] = .string(subpath)
        }
        return object
    }
}

struct ParsedURLMarketplaceSource: Equatable, Sendable {
    let url: String?
    let checksum: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("url")
        if let url {
            object["url"] = .string(url)
        }
        if let checksum {
            object["checksum"] = .string(checksum)
        }
        return object
    }
}

struct ParsedNpmMarketplaceSource: Equatable, Sendable {
    let package: String?
    let version: String?
    let registry: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("npm")
        if let package {
            object["package"] = .string(package)
        }
        if let version {
            object["version"] = .string(version)
        }
        if let registry {
            object["registry"] = .string(registry)
        }
        return object
    }
}

struct ParsedFileMarketplaceSource: Equatable, Sendable {
    let path: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("file")
        if let path {
            object["path"] = .string(path)
        }
        return object
    }
}

struct ParsedDirectoryMarketplaceSource: Equatable, Sendable {
    let path: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("directory")
        if let path {
            object["path"] = .string(path)
        }
        return object
    }
}

struct ParsedHostPatternMarketplaceSource: Equatable, Sendable {
    let pattern: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        object["type"] = .string("hostPattern")
        if let pattern {
            object["pattern"] = .string(pattern)
        }
        return object
    }
}

struct ParsedInlineMarketplaceSource: Equatable, Sendable {
    let rawObject: [String: JSONValue]
}

struct ParsedAllowedChannelPlugin: Equatable, Sendable {
    let plugin: String?
    let marketplace: String?
    let channels: [String]?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let plugin {
            object["plugin"] = .string(plugin)
        }
        if let marketplace {
            object["marketplace"] = .string(marketplace)
        }
        if let channels {
            object["channels"] = .array(channels.map(JSONValue.string))
        }
        return object
    }
}

struct SettingsDocumentValue: Equatable, Sendable {
    let schema: String?
    let apiKeyHelper: String?
    let forceLoginMethod: String?
    let forceLoginOrgUUID: String?
    let otelHeadersHelper: String?
    let awsAuthRefresh: String?
    let awsCredentialExport: String?
    let autoMemoryDirectory: String?
    let cleanupPeriodDays: Int?
    let companyAnnouncements: [String]?
    let model: String?
    let availableModels: [String]?
    let modelOverrides: [String: String]?
    let effortLevel: String?
    let alwaysThinkingEnabled: Bool?
    let fastMode: Bool?
    let fastModePerSessionOptIn: Bool?
    let feedbackSurveyRate: Double?
    let agent: String?
    let env: ParsedEnvMap?
    let attribution: ParsedAttribution?
    let statusLine: ParsedStatusLine?
    let fileSuggestion: ParsedFileSuggestion?
    let spinnerVerbs: ParsedSpinnerVerbs?
    let spinnerTipsOverride: ParsedSpinnerTipsOverride?
    let includeCoAuthoredBy: Bool?
    let includeGitInstructions: Bool?
    let permissions: ParsedPermissions?
    let allowManagedPermissionRulesOnly: Bool?
    let autoMode: Bool?
    let disableAutoMode: Bool?
    let useAutoModeDuringPlan: Bool?
    let worktree: ParsedWorktreeConfig?
    let plansDirectory: String?
    let autoUpdatesChannel: String?
    let disableDeepLinkRegistration: String?
    let hooks: ParsedHooks?
    let disableAllHooks: Bool?
    let allowManagedHooksOnly: Bool?
    let allowedHTTPHookURLs: [String]?
    let httpHookAllowedEnvVars: [String]?
    let allowManagedMcpServersOnly: Bool?
    let enableAllProjectMcpServers: Bool?
    let enabledMcpjsonServers: [String]?
    let disabledMcpjsonServers: [String]?
    let allowedMcpServers: [McpRestrictionRule]?
    let deniedMcpServers: [McpRestrictionRule]?
    let sandbox: ParsedSandboxConfig?
    let enabledPlugins: [String: Bool]?
    let extraKnownMarketplaces: [String: ParsedPluginMarketplace]?
    let strictKnownMarketplaces: [ParsedPluginMarketplace]?
    let blockedMarketplaces: [ParsedPluginMarketplace]?
    let pluginTrustMessage: String?
    let channelsEnabled: Bool?
    let allowedChannelPlugins: [ParsedAllowedChannelPlugin]?
    let language: String?
    let respectGitignore: Bool?
    let outputStyle: String?
    let defaultShell: String?
    let voiceEnabled: Bool?
    let prefersReducedMotion: Bool?
    let spinnerTipsEnabled: Bool?
    let showClearContextOnPlanAccept: Bool?
    let pluginSettings: [String: JSONValue]
    let keyedStorage: [String: JSONValue]
    let registryValues: [String: JSONValue]

    init(
        schema: String?,
        apiKeyHelper: String?,
        forceLoginMethod: String? = nil,
        forceLoginOrgUUID: String? = nil,
        otelHeadersHelper: String? = nil,
        awsAuthRefresh: String? = nil,
        awsCredentialExport: String? = nil,
        autoMemoryDirectory: String?,
        cleanupPeriodDays: Int?,
        companyAnnouncements: [String]?,
        model: String? = nil,
        availableModels: [String]? = nil,
        modelOverrides: [String: String]? = nil,
        effortLevel: String? = nil,
        alwaysThinkingEnabled: Bool? = nil,
        fastMode: Bool? = nil,
        fastModePerSessionOptIn: Bool? = nil,
        feedbackSurveyRate: Double? = nil,
        agent: String? = nil,
        env: ParsedEnvMap?,
        attribution: ParsedAttribution?,
        statusLine: ParsedStatusLine? = nil,
        fileSuggestion: ParsedFileSuggestion? = nil,
        spinnerVerbs: ParsedSpinnerVerbs? = nil,
        spinnerTipsOverride: ParsedSpinnerTipsOverride? = nil,
        includeCoAuthoredBy: Bool?,
        includeGitInstructions: Bool?,
        permissions: ParsedPermissions?,
        allowManagedPermissionRulesOnly: Bool? = nil,
        autoMode: Bool?,
        disableAutoMode: Bool?,
        useAutoModeDuringPlan: Bool?,
        worktree: ParsedWorktreeConfig? = nil,
        plansDirectory: String? = nil,
        autoUpdatesChannel: String? = nil,
        disableDeepLinkRegistration: String?,
        hooks: ParsedHooks?,
        disableAllHooks: Bool?,
        allowManagedHooksOnly: Bool?,
        allowedHTTPHookURLs: [String]?,
        httpHookAllowedEnvVars: [String]?,
        allowManagedMcpServersOnly: Bool? = nil,
        enableAllProjectMcpServers: Bool? = nil,
        enabledMcpjsonServers: [String]? = nil,
        disabledMcpjsonServers: [String]? = nil,
        allowedMcpServers: [McpRestrictionRule]? = nil,
        deniedMcpServers: [McpRestrictionRule]? = nil,
        sandbox: ParsedSandboxConfig? = nil,
        enabledPlugins: [String: Bool]? = nil,
        extraKnownMarketplaces: [String: ParsedPluginMarketplace]? = nil,
        strictKnownMarketplaces: [ParsedPluginMarketplace]? = nil,
        blockedMarketplaces: [ParsedPluginMarketplace]? = nil,
        pluginTrustMessage: String? = nil,
        channelsEnabled: Bool? = nil,
        allowedChannelPlugins: [ParsedAllowedChannelPlugin]? = nil,
        language: String? = nil,
        respectGitignore: Bool? = nil,
        outputStyle: String? = nil,
        defaultShell: String? = nil,
        voiceEnabled: Bool? = nil,
        prefersReducedMotion: Bool? = nil,
        spinnerTipsEnabled: Bool? = nil,
        showClearContextOnPlanAccept: Bool? = nil,
        pluginSettings: [String: JSONValue],
        keyedStorage: [String: JSONValue] = [:],
        registryValues: [String: JSONValue] = [:]
    ) {
        let synthesizedStorage = Self.makeSynthesizedStorage(
            schema: schema,
            apiKeyHelper: apiKeyHelper,
            forceLoginMethod: forceLoginMethod,
            forceLoginOrgUUID: forceLoginOrgUUID,
            otelHeadersHelper: otelHeadersHelper,
            awsAuthRefresh: awsAuthRefresh,
            awsCredentialExport: awsCredentialExport,
            autoMemoryDirectory: autoMemoryDirectory,
            cleanupPeriodDays: cleanupPeriodDays,
            companyAnnouncements: companyAnnouncements,
            model: model,
            availableModels: availableModels,
            modelOverrides: modelOverrides,
            effortLevel: effortLevel,
            alwaysThinkingEnabled: alwaysThinkingEnabled,
            fastMode: fastMode,
            fastModePerSessionOptIn: fastModePerSessionOptIn,
            feedbackSurveyRate: feedbackSurveyRate,
            agent: agent,
            env: env,
            attribution: attribution,
            statusLine: statusLine,
            fileSuggestion: fileSuggestion,
            spinnerVerbs: spinnerVerbs,
            spinnerTipsOverride: spinnerTipsOverride,
            includeCoAuthoredBy: includeCoAuthoredBy,
            includeGitInstructions: includeGitInstructions,
            permissions: permissions,
            allowManagedPermissionRulesOnly: allowManagedPermissionRulesOnly,
            autoMode: autoMode,
            disableAutoMode: disableAutoMode,
            useAutoModeDuringPlan: useAutoModeDuringPlan,
            worktree: worktree,
            plansDirectory: plansDirectory,
            autoUpdatesChannel: autoUpdatesChannel,
            disableDeepLinkRegistration: disableDeepLinkRegistration,
            hooks: hooks,
            disableAllHooks: disableAllHooks,
            allowManagedHooksOnly: allowManagedHooksOnly,
            allowedHTTPHookURLs: allowedHTTPHookURLs,
            httpHookAllowedEnvVars: httpHookAllowedEnvVars,
            allowManagedMcpServersOnly: allowManagedMcpServersOnly,
            enableAllProjectMcpServers: enableAllProjectMcpServers,
            enabledMcpjsonServers: enabledMcpjsonServers,
            disabledMcpjsonServers: disabledMcpjsonServers,
            allowedMcpServers: allowedMcpServers,
            deniedMcpServers: deniedMcpServers,
            sandbox: sandbox,
            enabledPlugins: enabledPlugins,
            extraKnownMarketplaces: extraKnownMarketplaces,
            strictKnownMarketplaces: strictKnownMarketplaces,
            blockedMarketplaces: blockedMarketplaces,
            pluginTrustMessage: pluginTrustMessage,
            channelsEnabled: channelsEnabled,
            allowedChannelPlugins: allowedChannelPlugins,
            language: language,
            respectGitignore: respectGitignore,
            outputStyle: outputStyle,
            defaultShell: defaultShell,
            voiceEnabled: voiceEnabled,
            prefersReducedMotion: prefersReducedMotion,
            spinnerTipsEnabled: spinnerTipsEnabled,
            showClearContextOnPlanAccept: showClearContextOnPlanAccept,
            pluginSettings: pluginSettings
        )
        let mergedKeyedStorage = synthesizedStorage
            .merging(registryValues) { _, rhs in rhs }
            .merging(keyedStorage) { _, rhs in rhs }

        self.schema = schema
        self.apiKeyHelper = apiKeyHelper
        self.forceLoginMethod = forceLoginMethod
        self.forceLoginOrgUUID = forceLoginOrgUUID
        self.otelHeadersHelper = otelHeadersHelper
        self.awsAuthRefresh = awsAuthRefresh
        self.awsCredentialExport = awsCredentialExport
        self.autoMemoryDirectory = autoMemoryDirectory
        self.cleanupPeriodDays = cleanupPeriodDays
        self.companyAnnouncements = companyAnnouncements
        self.model = model
        self.availableModels = availableModels
        self.modelOverrides = modelOverrides
        self.effortLevel = effortLevel
        self.alwaysThinkingEnabled = alwaysThinkingEnabled
        self.fastMode = fastMode
        self.fastModePerSessionOptIn = fastModePerSessionOptIn
        self.feedbackSurveyRate = feedbackSurveyRate
        self.agent = agent
        self.env = env
        self.attribution = attribution
        self.statusLine = statusLine
        self.fileSuggestion = fileSuggestion
        self.spinnerVerbs = spinnerVerbs
        self.spinnerTipsOverride = spinnerTipsOverride
        self.includeCoAuthoredBy = includeCoAuthoredBy
        self.includeGitInstructions = includeGitInstructions
        self.permissions = permissions
        self.allowManagedPermissionRulesOnly = allowManagedPermissionRulesOnly
        self.autoMode = autoMode
        self.disableAutoMode = disableAutoMode
        self.useAutoModeDuringPlan = useAutoModeDuringPlan
        self.worktree = worktree
        self.plansDirectory = plansDirectory
        self.autoUpdatesChannel = autoUpdatesChannel
        self.disableDeepLinkRegistration = disableDeepLinkRegistration
        self.hooks = hooks
        self.disableAllHooks = disableAllHooks
        self.allowManagedHooksOnly = allowManagedHooksOnly
        self.allowedHTTPHookURLs = allowedHTTPHookURLs
        self.httpHookAllowedEnvVars = httpHookAllowedEnvVars
        self.allowManagedMcpServersOnly = allowManagedMcpServersOnly
        self.enableAllProjectMcpServers = enableAllProjectMcpServers
        self.enabledMcpjsonServers = enabledMcpjsonServers
        self.disabledMcpjsonServers = disabledMcpjsonServers
        self.allowedMcpServers = allowedMcpServers
        self.deniedMcpServers = deniedMcpServers
        self.sandbox = sandbox
        self.enabledPlugins = enabledPlugins
        self.extraKnownMarketplaces = extraKnownMarketplaces
        self.strictKnownMarketplaces = strictKnownMarketplaces
        self.blockedMarketplaces = blockedMarketplaces
        self.pluginTrustMessage = pluginTrustMessage
        self.channelsEnabled = channelsEnabled
        self.allowedChannelPlugins = allowedChannelPlugins
        self.language = language
        self.respectGitignore = respectGitignore
        self.outputStyle = outputStyle
        self.defaultShell = defaultShell
        self.voiceEnabled = voiceEnabled
        self.prefersReducedMotion = prefersReducedMotion
        self.spinnerTipsEnabled = spinnerTipsEnabled
        self.showClearContextOnPlanAccept = showClearContextOnPlanAccept
        self.pluginSettings = pluginSettings
        self.keyedStorage = mergedKeyedStorage
        self.registryValues = registryValues.isEmpty
            ? mergedKeyedStorage.filter { SettingsKeyRegistry.shared.isKnownTopLevelKey($0.key) }
            : registryValues
    }

    func rawValue(for keyPath: String) -> JSONValue? {
        let components = keyPath.split(separator: ".").map(String.init)
        guard let first = components.first else {
            return nil
        }

        var current = keyedStorage[first]
        for component in components.dropFirst() {
            guard case .object(let object)? = current else {
                return nil
            }
            current = object[component]
        }

        return current
    }

    private static func makeSynthesizedStorage(
        schema: String?,
        apiKeyHelper: String?,
        forceLoginMethod: String?,
        forceLoginOrgUUID: String?,
        otelHeadersHelper: String?,
        awsAuthRefresh: String?,
        awsCredentialExport: String?,
        autoMemoryDirectory: String?,
        cleanupPeriodDays: Int?,
        companyAnnouncements: [String]?,
        model: String?,
        availableModels: [String]?,
        modelOverrides: [String: String]?,
        effortLevel: String?,
        alwaysThinkingEnabled: Bool?,
        fastMode: Bool?,
        fastModePerSessionOptIn: Bool?,
        feedbackSurveyRate: Double?,
        agent: String?,
        env: ParsedEnvMap?,
        attribution: ParsedAttribution?,
        statusLine: ParsedStatusLine?,
        fileSuggestion: ParsedFileSuggestion?,
        spinnerVerbs: ParsedSpinnerVerbs?,
        spinnerTipsOverride: ParsedSpinnerTipsOverride?,
        includeCoAuthoredBy: Bool?,
        includeGitInstructions: Bool?,
        permissions: ParsedPermissions?,
        allowManagedPermissionRulesOnly: Bool?,
        autoMode: Bool?,
        disableAutoMode: Bool?,
        useAutoModeDuringPlan: Bool?,
        worktree: ParsedWorktreeConfig?,
        plansDirectory: String?,
        autoUpdatesChannel: String?,
        disableDeepLinkRegistration: String?,
        hooks: ParsedHooks?,
        disableAllHooks: Bool?,
        allowManagedHooksOnly: Bool?,
        allowedHTTPHookURLs: [String]?,
        httpHookAllowedEnvVars: [String]?,
        allowManagedMcpServersOnly: Bool?,
        enableAllProjectMcpServers: Bool?,
        enabledMcpjsonServers: [String]?,
        disabledMcpjsonServers: [String]?,
        allowedMcpServers: [McpRestrictionRule]?,
        deniedMcpServers: [McpRestrictionRule]?,
        sandbox: ParsedSandboxConfig?,
        enabledPlugins: [String: Bool]?,
        extraKnownMarketplaces: [String: ParsedPluginMarketplace]?,
        strictKnownMarketplaces: [ParsedPluginMarketplace]?,
        blockedMarketplaces: [ParsedPluginMarketplace]?,
        pluginTrustMessage: String?,
        channelsEnabled: Bool?,
        allowedChannelPlugins: [ParsedAllowedChannelPlugin]?,
        language: String?,
        respectGitignore: Bool?,
        outputStyle: String?,
        defaultShell: String?,
        voiceEnabled: Bool?,
        prefersReducedMotion: Bool?,
        spinnerTipsEnabled: Bool?,
        showClearContextOnPlanAccept: Bool?,
        pluginSettings: [String: JSONValue]
    ) -> [String: JSONValue] {
        var storage = pluginSettings

        if let schema {
            storage["$schema"] = .string(schema)
        }
        if let apiKeyHelper {
            storage["apiKeyHelper"] = .string(apiKeyHelper)
        }
        if let forceLoginMethod {
            storage["forceLoginMethod"] = .string(forceLoginMethod)
        }
        if let forceLoginOrgUUID {
            storage["forceLoginOrgUUID"] = .string(forceLoginOrgUUID)
        }
        if let otelHeadersHelper {
            storage["otelHeadersHelper"] = .string(otelHeadersHelper)
        }
        if let awsAuthRefresh {
            storage["awsAuthRefresh"] = .string(awsAuthRefresh)
        }
        if let awsCredentialExport {
            storage["awsCredentialExport"] = .string(awsCredentialExport)
        }
        if let autoMemoryDirectory {
            storage["autoMemoryDirectory"] = .string(autoMemoryDirectory)
        }
        if let cleanupPeriodDays {
            storage["cleanupPeriodDays"] = .number(Double(cleanupPeriodDays))
        }
        if let companyAnnouncements {
            storage["companyAnnouncements"] = .array(companyAnnouncements.map(JSONValue.string))
        }
        if let model {
            storage["model"] = .string(model)
        }
        if let availableModels {
            storage["availableModels"] = .array(availableModels.map(JSONValue.string))
        }
        if let modelOverrides {
            storage["modelOverrides"] = .object(modelOverrides.mapValues(JSONValue.string))
        }
        if let effortLevel {
            storage["effortLevel"] = .string(effortLevel)
        }
        if let alwaysThinkingEnabled {
            storage["alwaysThinkingEnabled"] = .bool(alwaysThinkingEnabled)
        }
        if let fastMode {
            storage["fastMode"] = .bool(fastMode)
        }
        if let fastModePerSessionOptIn {
            storage["fastModePerSessionOptIn"] = .bool(fastModePerSessionOptIn)
        }
        if let feedbackSurveyRate {
            storage["feedbackSurveyRate"] = .number(feedbackSurveyRate)
        }
        if let agent {
            storage["agent"] = .string(agent)
        }
        if let env {
            storage["env"] = .object(env.rawObject)
        }
        if let attribution {
            storage["attribution"] = .object(attribution.rawObject)
        }
        if let statusLine {
            storage["statusLine"] = .object(statusLine.rawObject)
        }
        if let fileSuggestion {
            storage["fileSuggestion"] = .object(fileSuggestion.rawObject)
        }
        if let spinnerVerbs {
            storage["spinnerVerbs"] = .object(spinnerVerbs.rawObject)
        }
        if let spinnerTipsOverride {
            storage["spinnerTipsOverride"] = .object(spinnerTipsOverride.rawObject)
        }
        if let includeCoAuthoredBy {
            storage["includeCoAuthoredBy"] = .bool(includeCoAuthoredBy)
        }
        if let includeGitInstructions {
            storage["includeGitInstructions"] = .bool(includeGitInstructions)
        }
        if let permissions {
            storage["permissions"] = .object(permissions.rawObject)
        }
        if let allowManagedPermissionRulesOnly {
            storage["allowManagedPermissionRulesOnly"] = .bool(allowManagedPermissionRulesOnly)
        }
        if let autoMode {
            storage["autoMode"] = .bool(autoMode)
        }
        if let disableAutoMode {
            storage["disableAutoMode"] = .bool(disableAutoMode)
        }
        if let useAutoModeDuringPlan {
            storage["useAutoModeDuringPlan"] = .bool(useAutoModeDuringPlan)
        }
        if let worktree {
            storage["worktree"] = .object(worktree.rawObject)
        }
        if let plansDirectory {
            storage["plansDirectory"] = .string(plansDirectory)
        }
        if let autoUpdatesChannel {
            storage["autoUpdatesChannel"] = .string(autoUpdatesChannel)
        }
        if let disableDeepLinkRegistration {
            storage["disableDeepLinkRegistration"] = .string(disableDeepLinkRegistration)
        }
        if let hooks {
            storage["hooks"] = .object(hooks.rawObject)
        }
        if let disableAllHooks {
            storage["disableAllHooks"] = .bool(disableAllHooks)
        }
        if let allowManagedHooksOnly {
            storage["allowManagedHooksOnly"] = .bool(allowManagedHooksOnly)
        }
        if let allowedHTTPHookURLs {
            storage["allowedHttpHookUrls"] = .array(allowedHTTPHookURLs.map(JSONValue.string))
        }
        if let httpHookAllowedEnvVars {
            storage["httpHookAllowedEnvVars"] = .array(httpHookAllowedEnvVars.map(JSONValue.string))
        }
        if let allowManagedMcpServersOnly {
            storage["allowManagedMcpServersOnly"] = .bool(allowManagedMcpServersOnly)
        }
        if let enableAllProjectMcpServers {
            storage["enableAllProjectMcpServers"] = .bool(enableAllProjectMcpServers)
        }
        if let enabledMcpjsonServers {
            storage["enabledMcpjsonServers"] = .array(enabledMcpjsonServers.map(JSONValue.string))
        }
        if let disabledMcpjsonServers {
            storage["disabledMcpjsonServers"] = .array(disabledMcpjsonServers.map(JSONValue.string))
        }
        if let allowedMcpServers {
            storage["allowedMcpServers"] = .array(allowedMcpServers.map(\.jsonValue))
        }
        if let deniedMcpServers {
            storage["deniedMcpServers"] = .array(deniedMcpServers.map(\.jsonValue))
        }
        if let sandbox {
            storage["sandbox"] = .object(sandbox.rawObject)
        }
        if let enabledPlugins {
            storage["enabledPlugins"] = .object(enabledPlugins.mapValues(JSONValue.bool))
        }
        if let extraKnownMarketplaces {
            storage["extraKnownMarketplaces"] = .object(extraKnownMarketplaces.mapValues { JSONValue.object($0.rawObject) })
        }
        if let strictKnownMarketplaces {
            storage["strictKnownMarketplaces"] = .array(strictKnownMarketplaces.map { JSONValue.object($0.rawObject) })
        }
        if let blockedMarketplaces {
            storage["blockedMarketplaces"] = .array(blockedMarketplaces.map { JSONValue.object($0.rawObject) })
        }
        if let pluginTrustMessage {
            storage["pluginTrustMessage"] = .string(pluginTrustMessage)
        }
        if let channelsEnabled {
            storage["channelsEnabled"] = .bool(channelsEnabled)
        }
        if let allowedChannelPlugins {
            storage["allowedChannelPlugins"] = .array(allowedChannelPlugins.map { JSONValue.object($0.rawObject) })
        }
        if let language {
            storage["language"] = .string(language)
        }
        if let respectGitignore {
            storage["respectGitignore"] = .bool(respectGitignore)
        }
        if let outputStyle {
            storage["outputStyle"] = .string(outputStyle)
        }
        if let defaultShell {
            storage["defaultShell"] = .string(defaultShell)
        }
        if let voiceEnabled {
            storage["voiceEnabled"] = .bool(voiceEnabled)
        }
        if let prefersReducedMotion {
            storage["prefersReducedMotion"] = .bool(prefersReducedMotion)
        }
        if let spinnerTipsEnabled {
            storage["spinnerTipsEnabled"] = .bool(spinnerTipsEnabled)
        }
        if let showClearContextOnPlanAccept {
            storage["showClearContextOnPlanAccept"] = .bool(showClearContextOnPlanAccept)
        }

        return storage
    }
}

struct ParsedWorktreeConfig: Equatable, Sendable {
    let sparsePaths: [String]?
    let symlinkDirectories: [String]?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let sparsePaths {
            object["sparsePaths"] = .array(sparsePaths.map(JSONValue.string))
        }
        if let symlinkDirectories {
            object["symlinkDirectories"] = .array(symlinkDirectories.map(JSONValue.string))
        }
        return object
    }
}

struct McpRestrictionRule: Equatable, Sendable {
    let serverName: String?
    let serverCommand: [String]?
    let serverUrl: String?
    let unknownFields: [String: JSONValue]?

    var jsonValue: JSONValue {
        var object = unknownFields ?? [:]
        if let serverName {
            object["serverName"] = .string(serverName)
        }
        if let serverCommand {
            object["serverCommand"] = .array(serverCommand.map(JSONValue.string))
        }
        if let serverUrl {
            object["serverUrl"] = .string(serverUrl)
        }
        return .object(object)
    }
}

struct ParsedEnvMap: Equatable, Sendable {
    let values: [String: String]
    let rawObject: [String: JSONValue]
}

struct ParsedAttribution: Equatable, Sendable {
    let commit: String?
    let pr: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let commit {
            object["commit"] = .string(commit)
        }
        if let pr {
            object["pr"] = .string(pr)
        }
        return object
    }
}

struct ParsedStatusLine: Equatable, Sendable {
    let type: String?
    let command: String?
    let padding: Int?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let type {
            object["type"] = .string(type)
        }
        if let command {
            object["command"] = .string(command)
        }
        if let padding {
            object["padding"] = .number(Double(padding))
        }
        return object
    }
}

struct ParsedFileSuggestion: Equatable, Sendable {
    let type: String?
    let command: String?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let type {
            object["type"] = .string(type)
        }
        if let command {
            object["command"] = .string(command)
        }
        return object
    }
}

struct ParsedSpinnerVerbs: Equatable, Sendable {
    let mode: String?
    let verbs: [String]?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let mode {
            object["mode"] = .string(mode)
        }
        if let verbs {
            object["verbs"] = .array(verbs.map(JSONValue.string))
        }
        return object
    }
}

struct ParsedSpinnerTipsOverride: Equatable, Sendable {
    let excludeDefault: Bool?
    let tips: [String]?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let excludeDefault {
            object["excludeDefault"] = .bool(excludeDefault)
        }
        if let tips {
            object["tips"] = .array(tips.map(JSONValue.string))
        }
        return object
    }
}

struct ParsedPermissions: Equatable, Sendable {
    let allow: [String]?
    let deny: [String]?
    let ask: [String]?
    let defaultMode: String?
    let additionalDirectories: [String]?
    let disableBypassPermissionsMode: String?
    let rawObject: [String: JSONValue]

    init(
        allow: [String]?,
        deny: [String]?,
        ask: [String]? = nil,
        defaultMode: String? = nil,
        additionalDirectories: [String]? = nil,
        disableBypassPermissionsMode: String? = nil,
        rawObject: [String: JSONValue]
    ) {
        self.allow = allow
        self.deny = deny
        self.ask = ask
        self.defaultMode = defaultMode
        self.additionalDirectories = additionalDirectories
        self.disableBypassPermissionsMode = disableBypassPermissionsMode
        self.rawObject = rawObject
    }

    var mode: String? {
        defaultMode
    }
}

struct ParsedSandboxConfig: Equatable, Sendable {
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

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let enabled {
            object["enabled"] = .bool(enabled)
        }
        if let failIfUnavailable {
            object["failIfUnavailable"] = .bool(failIfUnavailable)
        }
        if let autoAllowBashIfSandboxed {
            object["autoAllowBashIfSandboxed"] = .bool(autoAllowBashIfSandboxed)
        }
        if let excludedCommands {
            object["excludedCommands"] = .array(excludedCommands.map(JSONValue.string))
        }
        if let allowUnsandboxedCommands {
            object["allowUnsandboxedCommands"] = .bool(allowUnsandboxedCommands)
        }
        if let enableWeakerNestedSandbox {
            object["enableWeakerNestedSandbox"] = .bool(enableWeakerNestedSandbox)
        }
        if let enableWeakerNetworkIsolation {
            object["enableWeakerNetworkIsolation"] = .bool(enableWeakerNetworkIsolation)
        }
        if let filesystem {
            object["filesystem"] = .object(filesystem.rawObject)
        }
        if let network {
            object["network"] = .object(network.rawObject)
        }
        return object
    }
}

struct ParsedSandboxFilesystem: Equatable, Sendable {
    let allowWrite: [String]?
    let denyWrite: [String]?
    let denyRead: [String]?
    let allowRead: [String]?
    let allowManagedReadPathsOnly: Bool?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let allowWrite {
            object["allowWrite"] = .array(allowWrite.map(JSONValue.string))
        }
        if let denyWrite {
            object["denyWrite"] = .array(denyWrite.map(JSONValue.string))
        }
        if let denyRead {
            object["denyRead"] = .array(denyRead.map(JSONValue.string))
        }
        if let allowRead {
            object["allowRead"] = .array(allowRead.map(JSONValue.string))
        }
        if let allowManagedReadPathsOnly {
            object["allowManagedReadPathsOnly"] = .bool(allowManagedReadPathsOnly)
        }
        return object
    }
}

struct ParsedSandboxNetwork: Equatable, Sendable {
    let allowUnixSockets: [String]?
    let allowAllUnixSockets: Bool?
    let allowLocalBinding: Bool?
    let allowedDomains: [String]?
    let allowManagedDomainsOnly: Bool?
    let httpProxyPort: Int?
    let socksProxyPort: Int?
    let unknownFields: [String: JSONValue]?

    var rawObject: [String: JSONValue] {
        var object = unknownFields ?? [:]
        if let allowUnixSockets {
            object["allowUnixSockets"] = .array(allowUnixSockets.map(JSONValue.string))
        }
        if let allowAllUnixSockets {
            object["allowAllUnixSockets"] = .bool(allowAllUnixSockets)
        }
        if let allowLocalBinding {
            object["allowLocalBinding"] = .bool(allowLocalBinding)
        }
        if let allowedDomains {
            object["allowedDomains"] = .array(allowedDomains.map(JSONValue.string))
        }
        if let allowManagedDomainsOnly {
            object["allowManagedDomainsOnly"] = .bool(allowManagedDomainsOnly)
        }
        if let httpProxyPort {
            object["httpProxyPort"] = .number(Double(httpProxyPort))
        }
        if let socksProxyPort {
            object["socksProxyPort"] = .number(Double(socksProxyPort))
        }
        return object
    }
}

struct ParsedHooks: Equatable, Sendable {
    let events: [String: ParsedHookEvent]
    let rawObject: [String: JSONValue]
}

enum HookEventType: Equatable, Hashable, Sendable {
    case sessionStart
    case sessionEnd
    case userPromptSubmit
    case preToolUse
    case postToolUse
    case postToolUseFailure
    case permissionRequest
    case notification
    case stop
    case stopFailure
    case subagentStart
    case subagentStop
    case preCompact
    case postCompact
    case instructionsLoaded
    case configChange
    case worktreeCreate
    case worktreeRemove
    case elicitation
    case elicitationResult
    case cwdChanged
    case fileChanged
    case taskCreated
    case taskCompleted
    case teammateIdle
    case setup
    case unknown(String)

    init(eventName: String) {
        switch Self.normalizedIdentifier(for: eventName) {
        case "sessionstart":
            self = .sessionStart
        case "sessionend":
            self = .sessionEnd
        case "userpromptsubmit":
            self = .userPromptSubmit
        case "pretooluse":
            self = .preToolUse
        case "posttooluse":
            self = .postToolUse
        case "posttoolusefailure":
            self = .postToolUseFailure
        case "permissionrequest":
            self = .permissionRequest
        case "notification":
            self = .notification
        case "stop":
            self = .stop
        case "stopfailure":
            self = .stopFailure
        case "subagentstart":
            self = .subagentStart
        case "subagentstop":
            self = .subagentStop
        case "precompact":
            self = .preCompact
        case "postcompact":
            self = .postCompact
        case "instructionsloaded":
            self = .instructionsLoaded
        case "configchange":
            self = .configChange
        case "worktreecreate":
            self = .worktreeCreate
        case "worktreeremove":
            self = .worktreeRemove
        case "elicitation":
            self = .elicitation
        case "elicitationresult":
            self = .elicitationResult
        case "cwdchanged":
            self = .cwdChanged
        case "filechanged":
            self = .fileChanged
        case "taskcreated":
            self = .taskCreated
        case "taskcompleted":
            self = .taskCompleted
        case "teammateidle":
            self = .teammateIdle
        case "setup":
            self = .setup
        default:
            self = .unknown(eventName)
        }
    }

    var canonicalName: String {
        switch self {
        case .sessionStart:
            return "SessionStart"
        case .sessionEnd:
            return "SessionEnd"
        case .userPromptSubmit:
            return "UserPromptSubmit"
        case .preToolUse:
            return "PreToolUse"
        case .postToolUse:
            return "PostToolUse"
        case .postToolUseFailure:
            return "PostToolUseFailure"
        case .permissionRequest:
            return "PermissionRequest"
        case .notification:
            return "Notification"
        case .stop:
            return "Stop"
        case .stopFailure:
            return "StopFailure"
        case .subagentStart:
            return "SubagentStart"
        case .subagentStop:
            return "SubagentStop"
        case .preCompact:
            return "PreCompact"
        case .postCompact:
            return "PostCompact"
        case .instructionsLoaded:
            return "InstructionsLoaded"
        case .configChange:
            return "ConfigChange"
        case .worktreeCreate:
            return "WorktreeCreate"
        case .worktreeRemove:
            return "WorktreeRemove"
        case .elicitation:
            return "Elicitation"
        case .elicitationResult:
            return "ElicitationResult"
        case .cwdChanged:
            return "CwdChanged"
        case .fileChanged:
            return "FileChanged"
        case .taskCreated:
            return "TaskCreated"
        case .taskCompleted:
            return "TaskCompleted"
        case .teammateIdle:
            return "TeammateIdle"
        case .setup:
            return "Setup"
        case .unknown(let eventName):
            return eventName
        }
    }

    var storageKey: String {
        canonicalName
    }

    var isKnown: Bool {
        if case .unknown = self {
            return false
        }
        return true
    }

    var isBlocking: Bool {
        switch self {
        case .userPromptSubmit, .preToolUse, .postToolUse, .permissionRequest, .stop, .subagentStop,
             .configChange, .worktreeCreate, .elicitation, .elicitationResult, .taskCreated,
             .taskCompleted, .teammateIdle:
            return true
        case .sessionStart, .sessionEnd, .postToolUseFailure, .notification, .stopFailure, .subagentStart,
             .preCompact, .postCompact, .instructionsLoaded, .worktreeRemove, .cwdChanged, .fileChanged,
             .setup, .unknown:
            return false
        }
    }

    var supportsContextInjection: Bool {
        switch self {
        case .userPromptSubmit, .preToolUse, .postToolUse, .stop:
            return true
        case .sessionStart, .sessionEnd, .postToolUseFailure, .permissionRequest, .notification,
             .stopFailure, .subagentStart, .subagentStop, .preCompact, .postCompact,
             .instructionsLoaded, .configChange, .worktreeCreate, .worktreeRemove, .elicitation,
             .elicitationResult, .cwdChanged, .fileChanged, .taskCreated, .taskCompleted,
             .teammateIdle, .setup, .unknown:
            return false
        }
    }

    var supportsPromptErasure: Bool {
        self == .userPromptSubmit
    }

    var sortKey: String {
        canonicalName
    }

    private static func normalizedIdentifier(for eventName: String) -> String {
        String(String.UnicodeScalarView(eventName.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })).lowercased()
    }
}

struct ParsedHookEvent: Equatable, Sendable {
    let eventName: String
    let eventType: HookEventType
    let matcher: String?
    let actions: [ParsedHookAction]
    let rawValue: JSONValue
}

enum HookHandlerType: String, Equatable, Sendable {
    case command
    case http
    case prompt
    case agent
}

struct ParsedHookAction: Equatable, Sendable {
    let type: String?
    let handlerType: HookHandlerType?
    let command: String?
    let url: String?
    let method: String?
    let body: String?
    let template: String?
    let agentId: String?
    let inputs: [String: JSONValue]?
    let prompt: String?
    let timeout: Int?
    let statusMessage: String?
    let condition: String?
    let once: Bool?
    let shell: String?
    let isAsync: Bool?
    let headers: [String: String]?
    let allowedEnvVars: [String]?
    let model: String?
    let rawObject: [String: JSONValue]
}

struct SettingsParser {
    private static let claudeJsonOnlyTopLevelKeys: Set<String> = [
        "autoConnectIde",
        "autoInstallIdeExtension",
        "editorMode",
        "showTurnDuration",
        "terminalProgressBarEnabled",
        "teammateMode"
    ]

    private let knownPermissionDefaultModes: Set<String> = [
        "default",
        "acceptEdits",
        "plan",
        "auto",
        "dontAsk",
        "bypassPermissions"
    ]
    private let knownEffortLevels: Set<String> = ["low", "medium", "high"]

    private let registry: SettingsKeyRegistry

    init(registry: SettingsKeyRegistry = .shared) {
        self.registry = registry
    }

    func parse(
        data: Data,
        sourceURL: URL,
        scope: ResolutionScope? = nil
    ) -> ParseResult<ParsedSettingsDocument> {
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
        issues.append(contentsOf: validateRegistryCoveredKeys(in: rawTopLevel, sourcePath: source.displayPath))

        let schema = parseString("$schema", from: root, sourcePath: source.displayPath, issues: &issues)
        let apiKeyHelper = parseString("apiKeyHelper", from: root, sourcePath: source.displayPath, issues: &issues)
        let forceLoginMethod = parseString("forceLoginMethod", from: root, sourcePath: source.displayPath, issues: &issues)
        let forceLoginOrgUUID = parseUUIDSetting(
            "forceLoginOrgUUID",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let otelHeadersHelper = parseString("otelHeadersHelper", from: root, sourcePath: source.displayPath, issues: &issues)
        let awsAuthRefresh = parseString("awsAuthRefresh", from: root, sourcePath: source.displayPath, issues: &issues)
        let awsCredentialExport = parseString("awsCredentialExport", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoMemoryDirectory = parseString("autoMemoryDirectory", from: root, sourcePath: source.displayPath, issues: &issues)
        let cleanupPeriodDays = parseNonNegativeInt(
            "cleanupPeriodDays",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let companyAnnouncements = parseStringArray("companyAnnouncements", from: root, sourcePath: source.displayPath, issues: &issues)
        let model = parseString("model", from: root, sourcePath: source.displayPath, issues: &issues)
        let availableModels = parseStringArray("availableModels", from: root, sourcePath: source.displayPath, issues: &issues)
        let modelOverrides = parseStringMap("modelOverrides", from: root, sourcePath: source.displayPath, issues: &issues)
        let effortLevel = parseEffortLevel(from: root, sourcePath: source.displayPath, issues: &issues)
        let alwaysThinkingEnabled = parseBool("alwaysThinkingEnabled", from: root, sourcePath: source.displayPath, issues: &issues)
        let fastMode = parseBool("fastMode", from: root, sourcePath: source.displayPath, issues: &issues)
        let fastModePerSessionOptIn = parseBool("fastModePerSessionOptIn", from: root, sourcePath: source.displayPath, issues: &issues)
        let feedbackSurveyRate = parseFeedbackSurveyRate(from: root, sourcePath: source.displayPath, issues: &issues)
        let agent = parseString("agent", from: root, sourcePath: source.displayPath, issues: &issues)
        let language = parseString("language", from: root, sourcePath: source.displayPath, issues: &issues)
        let respectGitignore = parseBool("respectGitignore", from: root, sourcePath: source.displayPath, issues: &issues)
        let outputStyle = parseString("outputStyle", from: root, sourcePath: source.displayPath, issues: &issues)
        let defaultShell = parseEnumString(
            "defaultShell",
            allowedValues: ["bash", "powershell"],
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let voiceEnabled = parseBool("voiceEnabled", from: root, sourcePath: source.displayPath, issues: &issues)
        let prefersReducedMotion = parseBool("prefersReducedMotion", from: root, sourcePath: source.displayPath, issues: &issues)
        let spinnerTipsEnabled = parseBool("spinnerTipsEnabled", from: root, sourcePath: source.displayPath, issues: &issues)
        let showClearContextOnPlanAccept = parseBool(
            "showClearContextOnPlanAccept",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let includeCoAuthoredBy = parseBool("includeCoAuthoredBy", from: root, sourcePath: source.displayPath, issues: &issues)
        if includeCoAuthoredBy != nil {
            issues.append(
                SyntaxIssue(
                    code: .deprecatedKey,
                    severity: .info,
                    message: "'includeCoAuthoredBy' is deprecated. Use 'attribution.commit' and 'attribution.pr' instead.",
                    sourcePath: source.displayPath,
                    keyPath: "includeCoAuthoredBy"
                )
            )
        }
        let includeGitInstructions = parseBool("includeGitInstructions", from: root, sourcePath: source.displayPath, issues: &issues)
        let allowManagedPermissionRulesOnly = parseBool("allowManagedPermissionRulesOnly", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoMode = parseBool("autoMode", from: root, sourcePath: source.displayPath, issues: &issues)
        let disableAutoMode = parseBool("disableAutoMode", from: root, sourcePath: source.displayPath, issues: &issues)
        let useAutoModeDuringPlan = parseBool("useAutoModeDuringPlan", from: root, sourcePath: source.displayPath, issues: &issues)
        let worktree = parseWorktree(from: root, sourcePath: source.displayPath, issues: &issues)
        let plansDirectory = parseString("plansDirectory", from: root, sourcePath: source.displayPath, issues: &issues)
        let autoUpdatesChannel = parseEnumString(
            "autoUpdatesChannel",
            allowedValues: ["stable", "latest"],
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let disableDeepLinkRegistration = parseDisableString(
            "disableDeepLinkRegistration",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let disableAllHooks = parseBool("disableAllHooks", from: root, sourcePath: source.displayPath, issues: &issues)
        let allowManagedHooksOnly = parseBool("allowManagedHooksOnly", from: root, sourcePath: source.displayPath, issues: &issues)
        let allowedHTTPHookURLs = parseStringArray("allowedHttpHookUrls", from: root, sourcePath: source.displayPath, issues: &issues)
        let httpHookAllowedEnvVars = parseStringArray("httpHookAllowedEnvVars", from: root, sourcePath: source.displayPath, issues: &issues)
        let allowManagedMcpServersOnly = parseManagedOnlyBool(
            "allowManagedMcpServersOnly",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            issues: &issues
        )
        let enableAllProjectMcpServers = parseBool("enableAllProjectMcpServers", from: root, sourcePath: source.displayPath, issues: &issues)
        let enabledMcpjsonServers = parseRequiredStringArraySetting(
            "enabledMcpjsonServers",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let disabledMcpjsonServers = parseRequiredStringArraySetting(
            "disabledMcpjsonServers",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )

        let env = parseEnv(from: root, sourcePath: source.displayPath, issues: &issues)
        let attribution = parseAttribution(from: root, sourcePath: source.displayPath, issues: &issues)
        let statusLine = parseStatusLine(from: root, sourcePath: source.displayPath, issues: &issues)
        let fileSuggestion = parseFileSuggestion(from: root, sourcePath: source.displayPath, issues: &issues)
        let spinnerVerbs = parseSpinnerVerbs(from: root, sourcePath: source.displayPath, issues: &issues)
        let spinnerTipsOverride = parseSpinnerTipsOverride(from: root, sourcePath: source.displayPath, issues: &issues)
        let permissions = parsePermissions(from: root, sourcePath: source.displayPath, issues: &issues)
        let hooks = parseHooks(from: root, sourcePath: source.displayPath, issues: &issues)
        let allowedMcpServers = parseMcpRestrictionRules(
            key: "allowedMcpServers",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            managedOnly: true,
            issues: &issues
        )
        let deniedMcpServers = parseMcpRestrictionRules(
            key: "deniedMcpServers",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            managedOnly: false,
            issues: &issues
        )
        let sandbox = parseSandbox(
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            issues: &issues
        )
        let enabledPlugins = parsePluginToggleMap(
            "enabledPlugins",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let extraKnownMarketplaces = parseMarketplaceDictionary(
            key: "extraKnownMarketplaces",
            from: root,
            sourcePath: source.displayPath,
            issues: &issues
        )
        let strictKnownMarketplaces = parseMarketplaceArray(
            key: "strictKnownMarketplaces",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            managedOnly: true,
            issues: &issues
        )
        let blockedMarketplaces = parseMarketplaceArray(
            key: "blockedMarketplaces",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            managedOnly: true,
            issues: &issues
        )
        let pluginTrustMessage = parseManagedOnlyString(
            "pluginTrustMessage",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            issues: &issues
        )
        let channelsEnabled = parseManagedOnlyBool(
            "channelsEnabled",
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            issues: &issues
        )
        let allowedChannelPlugins = parseAllowedChannelPlugins(
            from: root,
            sourcePath: source.displayPath,
            scope: scope,
            issues: &issues
        )

        let pluginSettings = rawTopLevel.filter { isPluginRelatedKey($0.key) }
        let registryValues = rawTopLevel.filter { registry.isKnownTopLevelKey($0.key) }

        var unsupportedTopLevelKeys: [String: JSONValue] = [:]
        for (key, value) in rawTopLevel where !registry.isKnownTopLevelKey(key) && !isPluginRelatedKey(key) {
            unsupportedTopLevelKeys[key] = value

            if Self.claudeJsonOnlyTopLevelKeys.contains(key) {
                issues.append(
                    SyntaxIssue(
                        code: .claudeJsonOnlyKeyInSettings,
                        severity: .warning,
                        message: "Key '\(key)' belongs in ~/.claude.json, not settings.json",
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

        let value = SettingsDocumentValue(
            schema: schema,
            apiKeyHelper: apiKeyHelper,
            forceLoginMethod: forceLoginMethod,
            forceLoginOrgUUID: forceLoginOrgUUID,
            otelHeadersHelper: otelHeadersHelper,
            awsAuthRefresh: awsAuthRefresh,
            awsCredentialExport: awsCredentialExport,
            autoMemoryDirectory: autoMemoryDirectory,
            cleanupPeriodDays: cleanupPeriodDays,
            companyAnnouncements: companyAnnouncements,
            model: model,
            availableModels: availableModels,
            modelOverrides: modelOverrides,
            effortLevel: effortLevel,
            alwaysThinkingEnabled: alwaysThinkingEnabled,
            fastMode: fastMode,
            fastModePerSessionOptIn: fastModePerSessionOptIn,
            feedbackSurveyRate: feedbackSurveyRate,
            agent: agent,
            env: env,
            attribution: attribution,
            statusLine: statusLine,
            fileSuggestion: fileSuggestion,
            spinnerVerbs: spinnerVerbs,
            spinnerTipsOverride: spinnerTipsOverride,
            includeCoAuthoredBy: includeCoAuthoredBy,
            includeGitInstructions: includeGitInstructions,
            permissions: permissions,
            allowManagedPermissionRulesOnly: allowManagedPermissionRulesOnly,
            autoMode: autoMode,
            disableAutoMode: disableAutoMode,
            useAutoModeDuringPlan: useAutoModeDuringPlan,
            worktree: worktree,
            plansDirectory: plansDirectory,
            autoUpdatesChannel: autoUpdatesChannel,
            disableDeepLinkRegistration: disableDeepLinkRegistration,
            hooks: hooks,
            disableAllHooks: disableAllHooks,
            allowManagedHooksOnly: allowManagedHooksOnly,
            allowedHTTPHookURLs: allowedHTTPHookURLs,
            httpHookAllowedEnvVars: httpHookAllowedEnvVars,
            allowManagedMcpServersOnly: allowManagedMcpServersOnly,
            enableAllProjectMcpServers: enableAllProjectMcpServers,
            enabledMcpjsonServers: enabledMcpjsonServers,
            disabledMcpjsonServers: disabledMcpjsonServers,
            allowedMcpServers: allowedMcpServers,
            deniedMcpServers: deniedMcpServers,
            sandbox: sandbox,
            enabledPlugins: enabledPlugins,
            extraKnownMarketplaces: extraKnownMarketplaces,
            strictKnownMarketplaces: strictKnownMarketplaces,
            blockedMarketplaces: blockedMarketplaces,
            pluginTrustMessage: pluginTrustMessage,
            channelsEnabled: channelsEnabled,
            allowedChannelPlugins: allowedChannelPlugins,
            language: language,
            respectGitignore: respectGitignore,
            outputStyle: outputStyle,
            defaultShell: defaultShell,
            voiceEnabled: voiceEnabled,
            prefersReducedMotion: prefersReducedMotion,
            spinnerTipsEnabled: spinnerTipsEnabled,
            showClearContextOnPlanAccept: showClearContextOnPlanAccept,
            pluginSettings: pluginSettings,
            keyedStorage: rawTopLevel,
            registryValues: registryValues
        )

        let document = ParsedSettingsDocument(
            source: source,
            value: value,
            rawTopLevelObject: rawTopLevel,
            unsupportedTopLevelKeys: unsupportedTopLevelKeys
        )

        // Run schema validation if scope is provided and no parse errors occurred
        if !issues.contains(where: { $0.severity == .error }), let scope = scope {
            let validator = SettingsValidator(registry: registry)
            let validationIssues = validator.validate(document, at: scope)
            issues.append(contentsOf: validationIssues)
        }

        return ParseResult(value: document, issues: issues)
    }

    func parse(
        jsonString: String,
        sourceURL: URL,
        scope: ResolutionScope? = nil
    ) -> ParseResult<ParsedSettingsDocument> {
        parse(data: Data(jsonString.utf8), sourceURL: sourceURL, scope: scope)
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
                        severity: .warning,
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
                    severity: .warning,
                    message: "'attribution' must be a JSON object.",
                    sourcePath: sourcePath,
                    keyPath: "attribution"
                )
            )
            return nil
        }

        let commit = parseString("commit", from: attributionObject, sourcePath: sourcePath, keyPathPrefix: "attribution", issues: &issues)
        let pr = parseString("pr", from: attributionObject, sourcePath: sourcePath, keyPathPrefix: "attribution", issues: &issues)
        let rawObject = attributionObject.mapValues { JSONValue.from(any: $0) }
        let unknownFields = rawObject.filter { !["commit", "pr"].contains($0.key) }

        return ParsedAttribution(
            commit: commit,
            pr: pr,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parseStatusLine(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedStatusLine? {
        parseObjectSetting(
            key: "statusLine",
            from: root,
            sourcePath: sourcePath,
            issues: &issues
        ) { object, rawObject, keyPath, issues in
            let type = parseString("type", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let command = parseString("command", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let padding = parseInt("padding", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "command", "padding"].contains($0.key) }
            return ParsedStatusLine(
                type: type,
                command: command,
                padding: padding,
                unknownFields: unknownFields.isEmpty ? nil : unknownFields
            )
        }
    }

    private func parseFileSuggestion(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedFileSuggestion? {
        parseObjectSetting(
            key: "fileSuggestion",
            from: root,
            sourcePath: sourcePath,
            issues: &issues
        ) { object, rawObject, keyPath, issues in
            let type = parseString("type", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let command = parseString("command", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "command"].contains($0.key) }
            return ParsedFileSuggestion(
                type: type,
                command: command,
                unknownFields: unknownFields.isEmpty ? nil : unknownFields
            )
        }
    }

    private func parseSpinnerVerbs(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedSpinnerVerbs? {
        parseObjectSetting(
            key: "spinnerVerbs",
            from: root,
            sourcePath: sourcePath,
            issues: &issues
        ) { object, rawObject, keyPath, issues in
            let mode = parseEnumString(
                "mode",
                allowedValues: ["append", "replace"],
                from: object,
                sourcePath: sourcePath,
                keyPathPrefix: keyPath,
                issues: &issues
            )
            let verbs = parseStringArray("verbs", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["mode", "verbs"].contains($0.key) }
            return ParsedSpinnerVerbs(
                mode: mode,
                verbs: verbs,
                unknownFields: unknownFields.isEmpty ? nil : unknownFields
            )
        }
    }

    private func parseSpinnerTipsOverride(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedSpinnerTipsOverride? {
        parseObjectSetting(
            key: "spinnerTipsOverride",
            from: root,
            sourcePath: sourcePath,
            issues: &issues
        ) { object, rawObject, keyPath, issues in
            let excludeDefault = parseBool("excludeDefault", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let tips = parseStringArray("tips", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["excludeDefault", "tips"].contains($0.key) }
            return ParsedSpinnerTipsOverride(
                excludeDefault: excludeDefault,
                tips: tips,
                unknownFields: unknownFields.isEmpty ? nil : unknownFields
            )
        }
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

        let ask = parseStringArray(
            "ask",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        )

        let defaultMode = parsePermissionDefaultMode(
            from: permissionsObject,
            sourcePath: sourcePath,
            issues: &issues
        )

        let additionalDirectories = parseStringArray(
            "additionalDirectories",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        )

        let disableBypassPermissionsMode = parseDisableBypassPermissionsMode(
            from: permissionsObject,
            sourcePath: sourcePath,
            issues: &issues
        )

        return ParsedPermissions(
            allow: allow,
            deny: deny,
            ask: ask,
            defaultMode: defaultMode,
            additionalDirectories: additionalDirectories,
            disableBypassPermissionsMode: disableBypassPermissionsMode,
            rawObject: permissionsObject.mapValues { JSONValue.from(any: $0) }
        )
    }

    private func parsePermissionDefaultMode(
        from permissionsObject: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> String? {
        let keyPath = "permissions.defaultMode"
        let defaultMode = parseString(
            "defaultMode",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        ) ?? parseString(
            "mode",
            from: permissionsObject,
            sourcePath: sourcePath,
            keyPathPrefix: "permissions",
            issues: &issues
        )

        guard let defaultMode else {
            return nil
        }

        guard knownPermissionDefaultModes.contains(defaultMode) else {
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .info,
                    message: "Unknown permissions.defaultMode '\(defaultMode)' was preserved for forward compatibility.",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return defaultMode
        }

        return defaultMode
    }

    private func parseDisableBypassPermissionsMode(
        from permissionsObject: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> String? {
        let keyPath = "permissions.disableBypassPermissionsMode"

        guard let rawValue = permissionsObject["disableBypassPermissionsMode"] else {
            return nil
        }

        guard let stringValue = rawValue as? String else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected string at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        guard stringValue == "disable" else {
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Expected \"disable\" at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return stringValue
        }

        return stringValue
    }

    private func parseEffortLevel(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> String? {
        guard let effortLevel = parseString("effortLevel", from: root, sourcePath: sourcePath, issues: &issues) else {
            return nil
        }

        guard knownEffortLevels.contains(effortLevel) else {
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Unknown effortLevel '\(effortLevel)' was preserved for forward compatibility.",
                    sourcePath: sourcePath,
                    keyPath: "effortLevel"
                )
            )
            return nil
        }

        return effortLevel
    }

    private func parseUUIDSetting(
        _ key: String,
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> String? {
        guard let stringValue = parseString(key, from: root, sourcePath: sourcePath, issues: &issues) else {
            return nil
        }

        guard UUID(uuidString: stringValue) != nil else {
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "\(key) should be a valid UUID string.",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        return stringValue
    }

    private func parseFeedbackSurveyRate(
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> Double? {
        let keyPath = "feedbackSurveyRate"
        guard let rawValue = root[keyPath] else {
            return nil
        }

        let numberValue: Double
        if let doubleValue = rawValue as? Double {
            numberValue = doubleValue
        } else if let intValue = rawValue as? Int {
            numberValue = Double(intValue)
        } else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected number at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        guard (0.0...1.0).contains(numberValue) else {
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "feedbackSurveyRate must be between 0 and 1 inclusive.",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return numberValue
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
            let eventType = HookEventType(eventName: eventName)

            if eventType.isKnown == false {
                issues.append(
                    SyntaxIssue(
                        code: .preservedUnknownHookEvent,
                        severity: .warning,
                        message: "Unknown hook event '\(eventName)' was preserved for forward compatibility.",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
            }

            if let actionsArray = eventValue as? [Any] {
                if
                    actionsArray.count == 1,
                    let groupObject = actionsArray.first as? [String: Any],
                    let nestedActions = groupObject["hooks"] as? [Any]
                {
                    let matcher = groupObject["matcher"] as? String
                    if groupObject["matcher"] != nil && matcher == nil {
                        issues.append(
                            SyntaxIssue(
                                code: .typeMismatch,
                                severity: .warning,
                                message: "Expected string at \(keyPath)[0].matcher.",
                                sourcePath: sourcePath,
                                keyPath: "\(keyPath)[0].matcher"
                            )
                        )
                    }
                    let actions = parseHookActions(
                        nestedActions,
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath)[0].hooks",
                        issues: &issues
                    )
                    events[eventName] = ParsedHookEvent(
                        eventName: eventName,
                        eventType: eventType,
                        matcher: matcher,
                        actions: actions,
                        rawValue: JSONValue.from(any: eventValue)
                    )
                    continue
                }

                let actions = parseHookActions(actionsArray, sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
                events[eventName] = ParsedHookEvent(
                    eventName: eventName,
                    eventType: eventType,
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
                        severity: .warning,
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
                    eventName: eventName,
                    eventType: eventType,
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
            let handlerType = type.flatMap { HookHandlerType(rawValue: $0.lowercased()) }
            let command = parseString("command", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let url = parseString("url", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let method = parseString("method", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let body = parseString("body", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let template = parseString("template", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let agentId = parseString("agent_id", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let inputs = parseJSONValueMap("inputs", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let prompt = parseString("prompt", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let timeout = parseHookTimeout(from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let statusMessage = parseString("statusMessage", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let condition = parseString("if", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let once = parseBool("once", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let shell = parseHookShell(from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let isAsync = parseBool("async", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let headers = parseStringMap("headers", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let allowedEnvVars = parseStringArray("allowedEnvVars", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)
            let model = parseString("model", from: actionObject, sourcePath: sourcePath, keyPathPrefix: itemPath, issues: &issues)

            validateHookActionShape(
                rawType: type,
                handlerType: handlerType,
                command: command,
                url: url,
                template: template,
                agentId: agentId,
                shell: shell,
                isAsync: isAsync,
                headers: headers,
                allowedEnvVars: allowedEnvVars,
                model: model,
                sourcePath: sourcePath,
                keyPath: itemPath,
                issues: &issues
            )

            parsedActions.append(
                ParsedHookAction(
                    type: type,
                    handlerType: handlerType,
                    command: command,
                    url: url,
                    method: method,
                    body: body,
                    template: template,
                    agentId: agentId,
                    inputs: inputs,
                    prompt: prompt,
                    timeout: timeout,
                    statusMessage: statusMessage,
                    condition: condition,
                    once: once,
                    shell: shell,
                    isAsync: isAsync,
                    headers: headers,
                    allowedEnvVars: allowedEnvVars,
                    model: model,
                    rawObject: actionObject.mapValues { JSONValue.from(any: $0) }
                )
            )
        }

        return parsedActions
    }

    private func validateHookActionShape(
        rawType: String?,
        handlerType: HookHandlerType?,
        command: String?,
        url: String?,
        template: String?,
        agentId: String?,
        shell: String?,
        isAsync: Bool?,
        headers: [String: String]?,
        allowedEnvVars: [String]?,
        model: String?,
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) {
        guard let rawType else {
            issues.append(
                SyntaxIssue(
                    code: .invalidHookShape,
                    severity: .error,
                    message: "Hook action must include a supported 'type' string.",
                    sourcePath: sourcePath,
                    keyPath: "\(keyPath).type"
                )
            )
            return
        }

        guard let handlerType else {
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .info,
                    message: "Unknown hook handler type '\(rawType)' was preserved for forward compatibility.",
                    sourcePath: sourcePath,
                    keyPath: "\(keyPath).type"
                )
            )
            return
        }

        switch handlerType {
        case .command:
            guard command != nil else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidHookShape,
                        severity: .error,
                        message: "Hook action type 'command' requires a 'command' string.",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).command"
                    )
                )
                return
            }
            warnAboutWrongHookProperty(propertyKey: "headers", valueIsPresent: headers != nil, handlerType: handlerType, allowedHandlerTypes: [.http], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "allowedEnvVars", valueIsPresent: allowedEnvVars != nil, handlerType: handlerType, allowedHandlerTypes: [.http], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "model", valueIsPresent: model != nil, handlerType: handlerType, allowedHandlerTypes: [.prompt, .agent], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
        case .http:
            guard url != nil else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidHookShape,
                        severity: .error,
                        message: "Hook action type 'http' requires a 'url' string.",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).url"
                    )
                )
                return
            }
            warnAboutWrongHookProperty(propertyKey: "shell", valueIsPresent: shell != nil, handlerType: handlerType, allowedHandlerTypes: [.command], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "async", valueIsPresent: isAsync != nil, handlerType: handlerType, allowedHandlerTypes: [.command], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "model", valueIsPresent: model != nil, handlerType: handlerType, allowedHandlerTypes: [.prompt, .agent], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
        case .prompt:
            guard template != nil else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidHookShape,
                        severity: .error,
                        message: "Hook action type 'prompt' requires a 'template' string.",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).template"
                    )
                )
                return
            }
            warnAboutWrongHookProperty(propertyKey: "shell", valueIsPresent: shell != nil, handlerType: handlerType, allowedHandlerTypes: [.command], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "async", valueIsPresent: isAsync != nil, handlerType: handlerType, allowedHandlerTypes: [.command], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "headers", valueIsPresent: headers != nil, handlerType: handlerType, allowedHandlerTypes: [.http], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "allowedEnvVars", valueIsPresent: allowedEnvVars != nil, handlerType: handlerType, allowedHandlerTypes: [.http], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
        case .agent:
            guard agentId != nil else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidHookShape,
                        severity: .error,
                        message: "Hook action type 'agent' requires an 'agent_id' string.",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).agent_id"
                    )
                )
                return
            }
            warnAboutWrongHookProperty(propertyKey: "shell", valueIsPresent: shell != nil, handlerType: handlerType, allowedHandlerTypes: [.command], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "async", valueIsPresent: isAsync != nil, handlerType: handlerType, allowedHandlerTypes: [.command], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "headers", valueIsPresent: headers != nil, handlerType: handlerType, allowedHandlerTypes: [.http], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
            warnAboutWrongHookProperty(propertyKey: "allowedEnvVars", valueIsPresent: allowedEnvVars != nil, handlerType: handlerType, allowedHandlerTypes: [.http], sourcePath: sourcePath, keyPath: keyPath, issues: &issues)
        }
    }

    private func warnAboutWrongHookProperty(
        propertyKey: String,
        valueIsPresent: Bool,
        handlerType: HookHandlerType,
        allowedHandlerTypes: Set<HookHandlerType>,
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) {
        guard valueIsPresent, allowedHandlerTypes.contains(handlerType) == false else {
            return
        }

        let expected = allowedHandlerTypes.map(\.rawValue).sorted().joined(separator: " or ")
        issues.append(
            SyntaxIssue(
                code: .invalidHookShape,
                severity: .warning,
                message: "Hook action property '\(propertyKey)' only applies to \(expected) handlers.",
                sourcePath: sourcePath,
                keyPath: "\(keyPath).\(propertyKey)"
            )
        )
    }

    private func parseHookTimeout(
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String,
        issues: inout [SyntaxIssue]
    ) -> Int? {
        parseInt("timeout", from: object, sourcePath: sourcePath, keyPathPrefix: keyPathPrefix, issues: &issues)
    }

    private func parseHookShell(
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String,
        issues: inout [SyntaxIssue]
    ) -> String? {
        guard let shell = parseString("shell", from: object, sourcePath: sourcePath, keyPathPrefix: keyPathPrefix, issues: &issues) else {
            return nil
        }

        switch shell {
        case "bash", "powershell":
            return shell
        default:
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Unsupported hook shell '\(shell)' was preserved for forward compatibility.",
                    sourcePath: sourcePath,
                    keyPath: "\(keyPathPrefix).shell"
                )
            )
            return shell
        }
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
                    severity: .warning,
                    message: "Expected string at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }
        return stringValue
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
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Unsupported value '\(stringValue)' at \(keyPath) was preserved for forward compatibility.",
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
                    severity: .warning,
                    message: "Expected bool at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }
        return boolValue
    }

    private func parseObjectSetting<Value>(
        key: String,
        from object: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue],
        build: ([String: Any], [String: JSONValue], String, inout [SyntaxIssue]) -> Value
    ) -> Value? {
        guard let rawValue = object[key] else {
            return nil
        }

        guard let nestedObject = rawValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected object at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        let rawObject = nestedObject.mapValues { JSONValue.from(any: $0) }
        return build(nestedObject, rawObject, key, &issues)
    }

    private func parseManagedOnlyBool(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) -> Bool? {
        let value = parseBool(
            key,
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: keyPathPrefix,
            issues: &issues
        )
        guard value != nil else {
            return nil
        }

        appendManagedOnlyScopeIssueIfNeeded(
            keyPath: buildKeyPath(prefix: keyPathPrefix, key: key),
            sourcePath: sourcePath,
            scope: scope,
            issues: &issues
        )

        return value
    }

    private func parseManagedOnlyString(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) -> String? {
        let value = parseString(
            key,
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: keyPathPrefix,
            issues: &issues
        )
        guard value != nil else {
            return nil
        }

        appendManagedOnlyScopeIssueIfNeeded(
            keyPath: buildKeyPath(prefix: keyPathPrefix, key: key),
            sourcePath: sourcePath,
            scope: scope,
            issues: &issues
        )

        return value
    }

    private func parseNonNegativeInt(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> Int? {
        guard let value = parseInt(
            key,
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: keyPathPrefix,
            issues: &issues
        ) else {
            return nil
        }

        guard value >= 0 else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Negative values are not supported at \(keyPath); the raw value was preserved for forward compatibility.",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return value
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
                    severity: .warning,
                    message: "Expected integer at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }
        return intValue
    }

    private func parseDisableString(
        _ key: String,
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

        guard stringValue == "disable" else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .warning,
                    message: "Unsupported value '\(stringValue)' at \(keyPath) was preserved for forward compatibility. Expected \"disable\".",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return stringValue
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
                    severity: .warning,
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
                        severity: .warning,
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

    private func parseWorktree(
        from object: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedWorktreeConfig? {
        guard let rawValue = object["worktree"] else {
            return nil
        }

        guard let worktreeObject = rawValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected object at worktree.",
                    sourcePath: sourcePath,
                    keyPath: "worktree"
                )
            )
            return nil
        }

        let rawObject = worktreeObject.mapValues { JSONValue.from(any: $0) }
        let sparsePaths = parseStringArray(
            "sparsePaths",
            from: worktreeObject,
            sourcePath: sourcePath,
            keyPathPrefix: "worktree",
            issues: &issues
        )
        let symlinkDirectories = parseStringArray(
            "symlinkDirectories",
            from: worktreeObject,
            sourcePath: sourcePath,
            keyPathPrefix: "worktree",
            issues: &issues
        )
        let unknownFields = rawObject.filter {
            $0.key != "sparsePaths" && $0.key != "symlinkDirectories"
        }

        return ParsedWorktreeConfig(
            sparsePaths: sparsePaths,
            symlinkDirectories: symlinkDirectories,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parseStringMap(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> [String: String]? {
        guard let rawValue = object[key] else {
            return nil
        }
        guard let rawObject = rawValue as? [String: Any] else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected object at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        var output: [String: String] = [:]
        for nestedKey in rawObject.keys.sorted() {
            guard let stringValue = rawObject[nestedKey] as? String else {
                let keyPath = "\(buildKeyPath(prefix: keyPathPrefix, key: key)).\(nestedKey)"
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected string at \(keyPath).",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                continue
            }

            output[nestedKey] = stringValue
        }

        return output
    }

    private func parseJSONValueMap(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        keyPathPrefix: String? = nil,
        issues: inout [SyntaxIssue]
    ) -> [String: JSONValue]? {
        guard let rawValue = object[key] else {
            return nil
        }
        guard let rawObject = rawValue as? [String: Any] else {
            let keyPath = buildKeyPath(prefix: keyPathPrefix, key: key)
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected object at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }
        return rawObject.mapValues { JSONValue.from(any: $0) }
    }

    private func parseRequiredStringArraySetting(
        _ key: String,
        from object: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [String]? {
        guard let rawValue = object[key] else {
            return nil
        }
        guard let anyArray = rawValue as? [Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected array at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        var output: [String] = []
        for (index, item) in anyArray.enumerated() {
            guard let itemString = item as? String else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected string entry at \(key)[\(index)].",
                        sourcePath: sourcePath,
                        keyPath: "\(key)[\(index)]"
                    )
                )
                continue
            }
            output.append(itemString)
        }

        return output
    }

    private func parseMcpRestrictionRules(
        key: String,
        from object: [String: Any],
        sourcePath: String,
        scope: ResolutionScope?,
        managedOnly: Bool,
        issues: inout [SyntaxIssue]
    ) -> [McpRestrictionRule]? {
        guard let rawValue = object[key] else {
            return nil
        }
        guard let ruleArray = rawValue as? [Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected array at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        if managedOnly {
            appendManagedOnlyScopeIssueIfNeeded(
                keyPath: key,
                sourcePath: sourcePath,
                scope: scope,
                issues: &issues
            )
        }

        var parsedRules: [McpRestrictionRule] = []
        parsedRules.reserveCapacity(ruleArray.count)

        for (index, item) in ruleArray.enumerated() {
            let itemKeyPath = "\(key)[\(index)]"
            guard let ruleObject = item as? [String: Any] else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object at \(itemKeyPath).",
                        sourcePath: sourcePath,
                        keyPath: itemKeyPath
                    )
                )
                continue
            }

            if let rule = parseMcpRestrictionRule(
                ruleObject,
                sourcePath: sourcePath,
                keyPath: itemKeyPath,
                issues: &issues
            ) {
                parsedRules.append(rule)
            }
        }

        return parsedRules
    }

    private func parseSandbox(
        from root: [String: Any],
        sourcePath: String,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) -> ParsedSandboxConfig? {
        guard let sandboxValue = root["sandbox"] else {
            return nil
        }
        guard let sandboxObject = sandboxValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected object at sandbox.",
                    sourcePath: sourcePath,
                    keyPath: "sandbox"
                )
            )
            return nil
        }

        let enabled = parseBool("enabled", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let failIfUnavailable = parseBool("failIfUnavailable", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let autoAllowBashIfSandboxed = parseBool("autoAllowBashIfSandboxed", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let excludedCommands = parseStringArray("excludedCommands", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let allowUnsandboxedCommands = parseBool("allowUnsandboxedCommands", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let enableWeakerNestedSandbox = parseBool("enableWeakerNestedSandbox", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let enableWeakerNetworkIsolation = parseBool("enableWeakerNetworkIsolation", from: sandboxObject, sourcePath: sourcePath, keyPathPrefix: "sandbox", issues: &issues)
        let filesystem = parseSandboxFilesystem(
            from: sandboxObject,
            sourcePath: sourcePath,
            scope: scope,
            issues: &issues
        )
        let network = parseSandboxNetwork(
            from: sandboxObject,
            sourcePath: sourcePath,
            scope: scope,
            issues: &issues
        )

        let rawObject = sandboxObject.mapValues { JSONValue.from(any: $0) }
        let unknownFields = rawObject.filter {
            $0.key != "enabled" &&
            $0.key != "failIfUnavailable" &&
            $0.key != "autoAllowBashIfSandboxed" &&
            $0.key != "excludedCommands" &&
            $0.key != "allowUnsandboxedCommands" &&
            $0.key != "enableWeakerNestedSandbox" &&
            $0.key != "enableWeakerNetworkIsolation" &&
            $0.key != "filesystem" &&
            $0.key != "network"
        }

        return ParsedSandboxConfig(
            enabled: enabled,
            failIfUnavailable: failIfUnavailable,
            autoAllowBashIfSandboxed: autoAllowBashIfSandboxed,
            excludedCommands: excludedCommands,
            allowUnsandboxedCommands: allowUnsandboxedCommands,
            enableWeakerNestedSandbox: enableWeakerNestedSandbox,
            enableWeakerNetworkIsolation: enableWeakerNetworkIsolation,
            filesystem: filesystem,
            network: network,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parseSandboxFilesystem(
        from sandboxObject: [String: Any],
        sourcePath: String,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) -> ParsedSandboxFilesystem? {
        guard let filesystemValue = sandboxObject["filesystem"] else {
            return nil
        }
        guard let filesystemObject = filesystemValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected object at sandbox.filesystem.",
                    sourcePath: sourcePath,
                    keyPath: "sandbox.filesystem"
                )
            )
            return nil
        }

        let allowWrite = parseStringArray("allowWrite", from: filesystemObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.filesystem", issues: &issues)
        let denyWrite = parseStringArray("denyWrite", from: filesystemObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.filesystem", issues: &issues)
        let denyRead = parseStringArray("denyRead", from: filesystemObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.filesystem", issues: &issues)
        let allowRead = parseStringArray("allowRead", from: filesystemObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.filesystem", issues: &issues)
        let allowManagedReadPathsOnly = parseManagedOnlyBool(
            "allowManagedReadPathsOnly",
            from: filesystemObject,
            sourcePath: sourcePath,
            keyPathPrefix: "sandbox.filesystem",
            scope: scope,
            issues: &issues
        )

        let rawObject = filesystemObject.mapValues { JSONValue.from(any: $0) }
        let unknownFields = rawObject.filter {
            $0.key != "allowWrite" &&
            $0.key != "denyWrite" &&
            $0.key != "denyRead" &&
            $0.key != "allowRead" &&
            $0.key != "allowManagedReadPathsOnly"
        }

        return ParsedSandboxFilesystem(
            allowWrite: allowWrite,
            denyWrite: denyWrite,
            denyRead: denyRead,
            allowRead: allowRead,
            allowManagedReadPathsOnly: allowManagedReadPathsOnly,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parseSandboxNetwork(
        from sandboxObject: [String: Any],
        sourcePath: String,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) -> ParsedSandboxNetwork? {
        guard let networkValue = sandboxObject["network"] else {
            return nil
        }
        guard let networkObject = networkValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected object at sandbox.network.",
                    sourcePath: sourcePath,
                    keyPath: "sandbox.network"
                )
            )
            return nil
        }

        let allowUnixSockets = parseStringArray("allowUnixSockets", from: networkObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.network", issues: &issues)
        let allowAllUnixSockets = parseBool("allowAllUnixSockets", from: networkObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.network", issues: &issues)
        let allowLocalBinding = parseBool("allowLocalBinding", from: networkObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.network", issues: &issues)
        let allowedDomains = parseStringArray("allowedDomains", from: networkObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.network", issues: &issues)
        let allowManagedDomainsOnly = parseManagedOnlyBool(
            "allowManagedDomainsOnly",
            from: networkObject,
            sourcePath: sourcePath,
            keyPathPrefix: "sandbox.network",
            scope: scope,
            issues: &issues
        )
        let httpProxyPort = parseInt("httpProxyPort", from: networkObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.network", issues: &issues)
        let socksProxyPort = parseInt("socksProxyPort", from: networkObject, sourcePath: sourcePath, keyPathPrefix: "sandbox.network", issues: &issues)

        if let port = httpProxyPort, !(1...65535).contains(port) {
            issues.append(
                SyntaxIssue(
                    code: .invalidValue,
                    severity: .warning,
                    message: "sandbox.network.httpProxyPort must be in range 1\u{2013}65535, got \(port).",
                    sourcePath: sourcePath,
                    keyPath: "sandbox.network.httpProxyPort"
                )
            )
        }
        if let port = socksProxyPort, !(1...65535).contains(port) {
            issues.append(
                SyntaxIssue(
                    code: .invalidValue,
                    severity: .warning,
                    message: "sandbox.network.socksProxyPort must be in range 1\u{2013}65535, got \(port).",
                    sourcePath: sourcePath,
                    keyPath: "sandbox.network.socksProxyPort"
                )
            )
        }

        if let domains = allowedDomains {
            for domain in domains where domain.isEmpty {
                issues.append(
                    SyntaxIssue(
                        code: .invalidValue,
                        severity: .warning,
                        message: "sandbox.network.allowedDomains contains an empty string; expected hostname string.",
                        sourcePath: sourcePath,
                        keyPath: "sandbox.network.allowedDomains"
                    )
                )
            }
        }

        let rawObject = networkObject.mapValues { JSONValue.from(any: $0) }
        let unknownFields = rawObject.filter {
            $0.key != "allowUnixSockets" &&
            $0.key != "allowAllUnixSockets" &&
            $0.key != "allowLocalBinding" &&
            $0.key != "allowedDomains" &&
            $0.key != "allowManagedDomainsOnly" &&
            $0.key != "httpProxyPort" &&
            $0.key != "socksProxyPort"
        }

        return ParsedSandboxNetwork(
            allowUnixSockets: allowUnixSockets,
            allowAllUnixSockets: allowAllUnixSockets,
            allowLocalBinding: allowLocalBinding,
            allowedDomains: allowedDomains,
            allowManagedDomainsOnly: allowManagedDomainsOnly,
            httpProxyPort: httpProxyPort,
            socksProxyPort: socksProxyPort,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parseMcpRestrictionRule(
        _ object: [String: Any],
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) -> McpRestrictionRule? {
        let rawObject = object.mapValues { JSONValue.from(any: $0) }
        let serverName = parseString(
            "serverName",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: keyPath,
            issues: &issues
        )
        let serverUrl = parseString(
            "serverUrl",
            from: object,
            sourcePath: sourcePath,
            keyPathPrefix: keyPath,
            issues: &issues
        )

        var serverCommand: [String]?
        if let rawServerCommand = object["serverCommand"] {
            if let commandArray = rawServerCommand as? [Any] {
                var parsedCommand: [String] = []
                for (index, item) in commandArray.enumerated() {
                    guard let commandSegment = item as? String else {
                        issues.append(
                            SyntaxIssue(
                                code: .typeMismatch,
                                severity: .warning,
                                message: "Expected string entry at \(keyPath).serverCommand[\(index)].",
                                sourcePath: sourcePath,
                                keyPath: "\(keyPath).serverCommand[\(index)]"
                            )
                        )
                        continue
                    }
                    parsedCommand.append(commandSegment)
                }
                serverCommand = parsedCommand
            } else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected array at \(keyPath).serverCommand.",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).serverCommand"
                    )
                )
            }
        }

        let discriminatorCount = [
            serverName != nil,
            serverCommand != nil,
            serverUrl != nil
        ].filter { $0 }.count

        guard discriminatorCount == 1 else {
            let message: String
            if discriminatorCount == 0 {
                message = "MCP restriction rules require exactly one of serverName, serverCommand, or serverUrl."
            } else {
                message = "MCP restriction rules cannot include multiple match keys."
            }
            issues.append(
                SyntaxIssue(
                    code: .invalidMcpRestrictionRule,
                    severity: .error,
                    message: message,
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        let unknownFields = rawObject.filter {
            $0.key != "serverName" &&
            $0.key != "serverCommand" &&
            $0.key != "serverUrl"
        }

        return McpRestrictionRule(
            serverName: serverName,
            serverCommand: serverCommand,
            serverUrl: serverUrl,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parsePluginToggleMap(
        _ key: String,
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [String: Bool]? {
        guard let rawValue = root[key] else {
            return nil
        }

        guard let object = rawValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected object at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        var parsed: [String: Bool] = [:]
        for pluginIdentifier in object.keys.sorted() {
            guard let enabled = object[pluginIdentifier] as? Bool else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected bool at \(key).\(pluginIdentifier).",
                        sourcePath: sourcePath,
                        keyPath: "\(key).\(pluginIdentifier)"
                    )
                )
                continue
            }
            parsed[pluginIdentifier] = enabled
        }

        return parsed
    }

    private func parseMarketplaceDictionary(
        key: String,
        from root: [String: Any],
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [String: ParsedPluginMarketplace]? {
        guard let rawValue = root[key] else {
            return nil
        }

        guard let object = rawValue as? [String: Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected object at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        var parsed: [String: ParsedPluginMarketplace] = [:]
        for marketplaceID in object.keys.sorted() {
            guard let entryObject = object[marketplaceID] as? [String: Any] else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object at \(key).\(marketplaceID).",
                        sourcePath: sourcePath,
                        keyPath: "\(key).\(marketplaceID)"
                    )
                )
                continue
            }

            let marketplace = parseMarketplace(
                entryObject,
                defaultID: marketplaceID,
                sourcePath: sourcePath,
                keyPath: "\(key).\(marketplaceID)",
                issues: &issues
            )
            parsed[marketplaceID] = marketplace
        }

        return parsed
    }

    private func parseMarketplaceArray(
        key: String,
        from root: [String: Any],
        sourcePath: String,
        scope: ResolutionScope?,
        managedOnly: Bool,
        issues: inout [SyntaxIssue]
    ) -> [ParsedPluginMarketplace]? {
        guard let rawValue = root[key] else {
            return nil
        }

        guard let array = rawValue as? [Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected array at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        if managedOnly {
            appendManagedOnlyScopeIssueIfNeeded(
                keyPath: key,
                sourcePath: sourcePath,
                scope: scope,
                issues: &issues
            )
        }

        var parsed: [ParsedPluginMarketplace] = []
        for (index, item) in array.enumerated() {
            guard let object = item as? [String: Any] else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object at \(key)[\(index)].",
                        sourcePath: sourcePath,
                        keyPath: "\(key)[\(index)]"
                    )
                )
                continue
            }

            parsed.append(
                parseMarketplace(
                    object,
                    defaultID: nil,
                    sourcePath: sourcePath,
                    keyPath: "\(key)[\(index)]",
                    issues: &issues
                )
            )
        }

        return parsed
    }

    private func parseMarketplace(
        _ object: [String: Any],
        defaultID: String?,
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedPluginMarketplace {
        let rawObject = object.mapValues { JSONValue.from(any: $0) }
        let id = parseString("id", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues) ?? defaultID

        let source: ParsedPluginMarketplaceSource?
        if let rawSource = object["source"] {
            if let sourceObject = rawSource as? [String: Any] {
                source = parseMarketplaceSource(
                    sourceObject,
                    sourcePath: sourcePath,
                    keyPath: "\(keyPath).source",
                    issues: &issues
                )
            } else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object at \(keyPath).source.",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath).source"
                    )
                )
                source = nil
            }
        } else if object.keys.contains("type") || containsInlineMarketplaceSourceKeys(object) {
            source = parseMarketplaceSource(
                object,
                sourcePath: sourcePath,
                keyPath: keyPath,
                issues: &issues
            )
        } else {
            source = nil
        }

        let unknownFields = rawObject.filter { $0.key != "id" && $0.key != "source" }
        return ParsedPluginMarketplace(
            id: id,
            source: source,
            unknownFields: unknownFields.isEmpty ? nil : unknownFields
        )
    }

    private func parseMarketplaceSource(
        _ object: [String: Any],
        sourcePath: String,
        keyPath: String,
        issues: inout [SyntaxIssue]
    ) -> ParsedPluginMarketplaceSource {
        let rawObject = object.mapValues { JSONValue.from(any: $0) }
        let type = parseString("type", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)

        switch type {
        case "github":
            let repo = parseString("repo", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let ref = parseString("ref", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let subpath = parseString("subpath", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "repo", "ref", "subpath"].contains($0.key) }
            return .github(
                ParsedGitHubMarketplaceSource(
                    repo: repo,
                    ref: ref,
                    subpath: subpath,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case "git":
            let url = parseString("url", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let ref = parseString("ref", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let subpath = parseString("subpath", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "url", "ref", "subpath"].contains($0.key) }
            return .git(
                ParsedGitMarketplaceSource(
                    url: url,
                    ref: ref,
                    subpath: subpath,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case "url":
            let url = parseString("url", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let checksum = parseString("checksum", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "url", "checksum"].contains($0.key) }
            return .url(
                ParsedURLMarketplaceSource(
                    url: url,
                    checksum: checksum,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case "npm":
            let package = parseString("package", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let version = parseString("version", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let registry = parseString("registry", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "package", "version", "registry"].contains($0.key) }
            return .npm(
                ParsedNpmMarketplaceSource(
                    package: package,
                    version: version,
                    registry: registry,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case "file":
            let path = parseString("path", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "path"].contains($0.key) }
            return .file(
                ParsedFileMarketplaceSource(
                    path: path,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case "directory":
            let path = parseString("path", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "path"].contains($0.key) }
            return .directory(
                ParsedDirectoryMarketplaceSource(
                    path: path,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case "hostPattern":
            let pattern = parseString("pattern", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
                ?? parseString("hostPattern", from: object, sourcePath: sourcePath, keyPathPrefix: keyPath, issues: &issues)
            let unknownFields = rawObject.filter { !["type", "pattern", "hostPattern"].contains($0.key) }
            return .hostPattern(
                ParsedHostPatternMarketplaceSource(
                    pattern: pattern,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        case .some(let type):
            issues.append(
                SyntaxIssue(
                    code: .preservedUnknownValue,
                    severity: .info,
                    message: "Unknown marketplace source type '\(type)' was preserved for forward compatibility.",
                    sourcePath: sourcePath,
                    keyPath: "\(keyPath).type"
                )
            )
            return .unknown(type: type, rawObject: rawObject)
        case .none:
            return .inline(ParsedInlineMarketplaceSource(rawObject: rawObject))
        }
    }

    private func parseAllowedChannelPlugins(
        from root: [String: Any],
        sourcePath: String,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) -> [ParsedAllowedChannelPlugin]? {
        let key = "allowedChannelPlugins"
        guard let rawValue = root[key] else {
            return nil
        }

        guard let array = rawValue as? [Any] else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .warning,
                    message: "Expected array at \(key).",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            )
            return nil
        }

        appendManagedOnlyScopeIssueIfNeeded(
            keyPath: key,
            sourcePath: sourcePath,
            scope: scope,
            issues: &issues
        )

        var parsed: [ParsedAllowedChannelPlugin] = []
        for (index, item) in array.enumerated() {
            guard let object = item as? [String: Any] else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object at \(key)[\(index)].",
                        sourcePath: sourcePath,
                        keyPath: "\(key)[\(index)]"
                    )
                )
                continue
            }

            let rawObject = object.mapValues { JSONValue.from(any: $0) }
            let plugin = parseString(
                "plugin",
                from: object,
                sourcePath: sourcePath,
                keyPathPrefix: "\(key)[\(index)]",
                issues: &issues
            ) ?? parseString(
                "id",
                from: object,
                sourcePath: sourcePath,
                keyPathPrefix: "\(key)[\(index)]",
                issues: &issues
            )
            let marketplace = parseString(
                "marketplace",
                from: object,
                sourcePath: sourcePath,
                keyPathPrefix: "\(key)[\(index)]",
                issues: &issues
            )
            let channels = parseStringArray(
                "channels",
                from: object,
                sourcePath: sourcePath,
                keyPathPrefix: "\(key)[\(index)]",
                issues: &issues
            )
            let unknownFields = rawObject.filter { !["plugin", "id", "marketplace", "channels"].contains($0.key) }

            parsed.append(
                ParsedAllowedChannelPlugin(
                    plugin: plugin,
                    marketplace: marketplace,
                    channels: channels,
                    unknownFields: unknownFields.isEmpty ? nil : unknownFields
                )
            )
        }

        return parsed
    }

    private func containsInlineMarketplaceSourceKeys(_ object: [String: Any]) -> Bool {
        let sourceKeys: Set<String> = [
            "repo",
            "ref",
            "subpath",
            "url",
            "package",
            "version",
            "registry",
            "path",
            "pattern",
            "hostPattern"
        ]
        return object.keys.contains(where: { sourceKeys.contains($0) })
    }

    private func appendManagedOnlyScopeIssueIfNeeded(
        keyPath: String,
        sourcePath: String,
        scope: ResolutionScope?,
        issues: inout [SyntaxIssue]
    ) {
        guard let scope, scope != .managed else {
            return
        }

        issues.append(
            SyntaxIssue(
                code: .managedOnlySettingInNonManagedScope,
                severity: .warning,
                message: "'\(keyPath)' is a managed-only setting but appeared in \(scope.rawValue) scope.",
                sourcePath: sourcePath,
                keyPath: keyPath
            )
        )
    }

    private func buildKeyPath(prefix: String?, key: String) -> String {
        guard let prefix, !prefix.isEmpty else {
            return key
        }
        return "\(prefix).\(key)"
    }

    private func validateRegistryCoveredKeys(
        in rawTopLevel: [String: JSONValue],
        sourcePath: String
    ) -> [SyntaxIssue] {
        var issues: [SyntaxIssue] = []
        let bespokeValidationTopLevelKeys: Set<String> = [
            "$schema",
            "apiKeyHelper",
            "autoMemoryDirectory",
            "cleanupPeriodDays",
            "companyAnnouncements",
            "model",
            "availableModels",
            "modelOverrides",
            "effortLevel",
            "alwaysThinkingEnabled",
            "fastMode",
            "fastModePerSessionOptIn",
            "feedbackSurveyRate",
            "agent",
            "env",
            "attribution",
            "statusLine",
            "fileSuggestion",
            "spinnerVerbs",
            "spinnerTipsOverride",
            "includeCoAuthoredBy",
            "includeGitInstructions",
            "permissions",
            "allowManagedPermissionRulesOnly",
            "autoMode",
            "disableAutoMode",
            "useAutoModeDuringPlan",
            "worktree",
            "plansDirectory",
            "autoUpdatesChannel",
            "disableDeepLinkRegistration",
            "hooks",
            "allowManagedHooksOnly",
            "allowedHttpHookUrls",
            "httpHookAllowedEnvVars",
            "allowManagedMcpServersOnly",
            "enableAllProjectMcpServers",
            "enabledMcpjsonServers",
            "disabledMcpjsonServers",
            "allowedMcpServers",
            "deniedMcpServers",
            "sandbox",
            "enabledPlugins",
            "extraKnownMarketplaces",
            "strictKnownMarketplaces",
            "blockedMarketplaces",
            "pluginTrustMessage",
            "channelsEnabled",
            "allowedChannelPlugins",
            "language",
            "respectGitignore",
            "outputStyle",
            "defaultShell",
            "voiceEnabled",
            "prefersReducedMotion",
            "spinnerTipsEnabled",
            "showClearContextOnPlanAccept"
        ]

        for (key, value) in rawTopLevel.sorted(by: { $0.key < $1.key }) {
            if let definition = registry.matchingDefinition(forTopLevelKey: key) {
                guard !bespokeValidationTopLevelKeys.contains(key) else {
                    continue
                }
                issues.append(contentsOf: validate(value: value, for: definition, sourcePath: sourcePath))
            } else if !bespokeValidationTopLevelKeys.contains(key) {
                // Emit info-level issue for unknown keys
                issues.append(
                    SyntaxIssue(
                        code: .unknownKey,
                        severity: .info,
                        message: "Unknown settings key: \"\(key)\"",
                        sourcePath: sourcePath,
                        keyPath: key
                    )
                )
            }
        }

        return issues
    }

    private func validate(
        value: JSONValue,
        for definition: SettingsKeyDefinition,
        sourcePath: String
    ) -> [SyntaxIssue] {
        guard !definition.type.matches(value) else {
            return []
        }

        return [
            SyntaxIssue(
                code: .typeMismatch,
                severity: .warning,
                message: "Expected \(definition.type.displayName) at \(definition.keyPath).",
                sourcePath: sourcePath,
                keyPath: definition.keyPath
            )
        ]
    }

    private func isPluginRelatedKey(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased == "plugins"
            || lowercased.hasPrefix("plugin")
            || lowercased.hasSuffix("plugins")
            || lowercased.contains("plugin")
            || lowercased.contains("marketplace")
            || lowercased.contains("channel")
    }
}
