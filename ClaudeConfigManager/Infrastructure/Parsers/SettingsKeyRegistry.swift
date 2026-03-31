import Foundation

enum SettingsKeyCategory: String, CaseIterable, Equatable, Sendable {
    case general
    case environmentHelpers
    case attributionGitBehavior
    case modelReasoning
    case permissions
    case hooksHookPolicy
    case mcpControls
    case sandbox
    case pluginsMarketplaces
    case authenticationIdentity
    case memoryClaudeMd
    case uiSessionExperience
    case worktree
    case operations
}

indirect enum SettingsKeyType: Equatable, Sendable {
    case string
    case bool
    case integer
    case number
    case stringArray
    case anyArray
    case object(properties: [String: SettingsKeyType], allowAdditionalProperties: Bool)
    case dictionary(value: SettingsKeyType)
    case array(element: SettingsKeyType)
    case oneOf([SettingsKeyType])
    case anyValue

    var displayName: String {
        switch self {
        case .string:
            return "string"
        case .bool:
            return "bool"
        case .integer:
            return "integer"
        case .number:
            return "number"
        case .stringArray:
            return "string array"
        case .anyArray:
            return "array"
        case .object:
            return "object"
        case .dictionary:
            return "object"
        case .array(let element):
            return "\(element.displayName) array"
        case .oneOf(let shapes):
            return shapes.map(\.displayName).joined(separator: " or ")
        case .anyValue:
            return "value"
        }
    }

    func matches(_ value: JSONValue) -> Bool {
        switch self {
        case .string:
            if case .string = value { return true }
            return false
        case .bool:
            if case .bool = value { return true }
            return false
        case .integer:
            guard case .number(let number) = value else { return false }
            return floor(number) == number
        case .number:
            if case .number = value { return true }
            return false
        case .stringArray:
            guard case .array(let values) = value else { return false }
            return values.allSatisfy {
                if case .string = $0 { return true }
                return false
            }
        case .anyArray:
            if case .array = value { return true }
            return false
        case .object(let properties, _):
            guard case .object(let object) = value else { return false }
            for (key, shape) in properties {
                guard let nestedValue = object[key] else { continue }
                guard shape.matches(nestedValue) else { return false }
            }
            return true
        case .dictionary(let nestedValueType):
            guard case .object(let object) = value else { return false }
            return object.values.allSatisfy { nestedValueType.matches($0) }
        case .array(let element):
            guard case .array(let values) = value else { return false }
            return values.allSatisfy { element.matches($0) }
        case .oneOf(let shapes):
            return shapes.contains { $0.matches(value) }
        case .anyValue:
            return true
        }
    }
}

struct SettingsKeyDefinition: Equatable, Sendable {
    let keyPath: String
    let type: SettingsKeyType
    let category: SettingsKeyCategory
    let description: String
    let isManagedOnly: Bool
    let applicableScopes: Set<ResolutionScope>
    let mergeHint: MergeMethod
    let isAdvanced: Bool
    let isReadOnlyDiagnostic: Bool

    init(
        keyPath: String,
        type: SettingsKeyType,
        category: SettingsKeyCategory,
        description: String,
        isManagedOnly: Bool = false,
        applicableScopes: Set<ResolutionScope> = [.managed, .user, .project, .projectLocal],
        mergeHint: MergeMethod = .selectHighestPrecedence,
        isAdvanced: Bool = false,
        isReadOnlyDiagnostic: Bool = false
    ) {
        self.keyPath = keyPath
        self.type = type
        self.category = category
        self.description = description
        self.isManagedOnly = isManagedOnly
        self.applicableScopes = applicableScopes
        self.mergeHint = mergeHint
        self.isAdvanced = isAdvanced
        self.isReadOnlyDiagnostic = isReadOnlyDiagnostic
    }
}

struct SettingsKeyRegistry: Sendable {
    static let shared = SettingsKeyRegistry()

    let definitionsByKeyPath: [String: SettingsKeyDefinition]

    init(definitions: [SettingsKeyDefinition] = SettingsKeyRegistry.defaultDefinitions) {
        self.definitionsByKeyPath = Dictionary(uniqueKeysWithValues: definitions.map { ($0.keyPath, $0) })
    }

    var allDefinitions: [SettingsKeyDefinition] {
        definitionsByKeyPath.values.sorted { $0.keyPath < $1.keyPath }
    }

    func definition(for keyPath: String) -> SettingsKeyDefinition? {
        definitionsByKeyPath[keyPath]
    }

    func isKnownTopLevelKey(_ key: String) -> Bool {
        definitionsByKeyPath[key] != nil || definitionsByKeyPath.keys.contains(where: { $0.hasPrefix("\(key).") })
    }

    func matchingDefinition(forTopLevelKey key: String) -> SettingsKeyDefinition? {
        definition(for: key)
    }
}

private extension SettingsKeyRegistry {
    static let defaultDefinitions: [SettingsKeyDefinition] = [
        definition("$schema", .string, .general, "Schema URL for settings documents."),
        definition("apiKeyHelper", .string, .authenticationIdentity, "Command used to resolve an API key."),
        definition("forceLoginMethod", .string, .authenticationIdentity, "Forces a specific Claude Code login method."),
        definition("forceLoginOrgUUID", .string, .authenticationIdentity, "Forces login against a specific organization UUID."),
        definition("otelHeadersHelper", .string, .environmentHelpers, "Command used to resolve OpenTelemetry headers."),
        definition("awsAuthRefresh", .string, .environmentHelpers, "Command used to refresh AWS authentication state."),
        definition("awsCredentialExport", .string, .environmentHelpers, "Command used to export AWS credentials."),
        definition("cleanupPeriodDays", .integer, .operations, "Retention window for local cleanup."),
        definition("companyAnnouncements", .stringArray, .operations, "Startup announcements shown by Claude Code.", mergeHint: .appendUnique),
        definition("env", .dictionary(value: .string), .environmentHelpers, "Environment variables injected into Claude Code.", mergeHint: .deepMergeObject),
        definition("attribution", .object(properties: [
            "commit": .string,
            "pr": .string
        ], allowAdditionalProperties: true), .attributionGitBehavior, "Commit and PR attribution preferences.", mergeHint: .deepMergeObject),
        definition("includeCoAuthoredBy", .bool, .attributionGitBehavior, "Deprecated top-level co-author toggle."),
        definition("includeGitInstructions", .bool, .attributionGitBehavior, "Whether Claude should include git workflow guidance."),
        definition("autoMode", .bool, .modelReasoning, "Enables auto mode by default."),
        definition("disableAutoMode", .bool, .modelReasoning, "Disables auto mode."),
        definition("useAutoModeDuringPlan", .bool, .modelReasoning, "Allows auto mode while planning.", applicableScopes: [.managed, .user, .projectLocal]),
        definition("alwaysThinkingEnabled", .bool, .modelReasoning, "Keeps thinking mode enabled by default."),
        definition("fastMode", .bool, .modelReasoning, "Enables fast mode."),
        definition("fastModePerSessionOptIn", .bool, .modelReasoning, "Requires per-session opt-in for fast mode."),
        definition("model", .string, .modelReasoning, "Default model selection."),
        definition("availableModels", .stringArray, .modelReasoning, "Restricts the selectable models.", mergeHint: .selectHighestPrecedence),
        definition("modelOverrides", .dictionary(value: .string), .modelReasoning, "Maps model identifiers to provider identifiers."),
        definition("effortLevel", .string, .modelReasoning, "Persisted effort level."),
        definition("reasoning", .string, .modelReasoning, "Reasoning mode preference."),
        definition("feedbackSurveyRate", .number, .modelReasoning, "Sampling rate for feedback surveys."),
        definition("agent", .string, .modelReasoning, "Named subagent for the main thread."),
        definition("permissions", .object(properties: [
            "allow": .stringArray,
            "deny": .stringArray,
            "ask": .stringArray,
            "defaultMode": .string,
            "additionalDirectories": .stringArray,
            "disableBypassPermissionsMode": .string
        ], allowAdditionalProperties: true), .permissions, "Permissions policy family.", mergeHint: .deepMergeObject),
        definition("permissions.allow", .stringArray, .permissions, "Permission allow rules.", mergeHint: .appendUnique),
        definition("permissions.deny", .stringArray, .permissions, "Permission deny rules.", mergeHint: .appendUnique),
        definition("permissions.ask", .stringArray, .permissions, "Permission rules that require confirmation.", mergeHint: .appendUnique),
        definition("permissions.defaultMode", .string, .permissions, "Default permission mode."),
        definition("permissions.additionalDirectories", .stringArray, .permissions, "Additional working directories allowed for commands.", mergeHint: .appendUnique),
        definition("permissions.disableBypassPermissionsMode", .string, .permissions, "Disables bypass mode when set to \"disable\"."),
        definition("allowManagedPermissionRulesOnly", .bool, .permissions, "Restricts permission rules to managed sources.", isManagedOnly: true),
        definition("hooks", .dictionary(value: .oneOf([
            .anyArray,
            .object(properties: [
                "matcher": .string,
                "hooks": .anyArray
            ], allowAdditionalProperties: true)
        ])), .hooksHookPolicy, "Hook event definitions.", mergeHint: .deepMergeObject),
        definition("disableAllHooks", .bool, .hooksHookPolicy, "Disables all configured hooks and custom status line behavior."),
        definition("allowManagedHooksOnly", .bool, .hooksHookPolicy, "Restricts hooks to managed sources.", isManagedOnly: true),
        definition("allowedHttpHookUrls", .stringArray, .hooksHookPolicy, "Allowlist for outbound HTTP hook URLs.", mergeHint: .appendUnique),
        definition("httpHookAllowedEnvVars", .stringArray, .hooksHookPolicy, "Environment variables exposed to HTTP hooks.", mergeHint: .appendUnique),
        definition("allowedHookDomains", .stringArray, .hooksHookPolicy, "Allowlist for hook domains.", mergeHint: .appendUnique),
        definition("mcpServers", .dictionary(value: .object(properties: [:], allowAdditionalProperties: true)), .mcpControls, "Configured MCP servers.", mergeHint: .deepMergeObject),
        definition("allowManagedMcpServersOnly", .bool, .mcpControls, "Restricts MCP allow rules to managed sources.", isManagedOnly: true),
        definition("allowedMcpServers", .array(element: .object(properties: [
            "serverName": .string,
            "serverCommand": .stringArray,
            "serverUrl": .string
        ], allowAdditionalProperties: true)), .mcpControls, "Allow rules for MCP servers.", isManagedOnly: true, mergeHint: .appendUnique),
        definition("deniedMcpServers", .array(element: .object(properties: [
            "serverName": .string,
            "serverCommand": .stringArray,
            "serverUrl": .string
        ], allowAdditionalProperties: true)), .mcpControls, "Deny rules for MCP servers.", mergeHint: .appendUnique),
        definition("enableAllProjectMcpServers", .bool, .mcpControls, "Auto-enables all project MCP servers."),
        definition("enabledMcpjsonServers", .stringArray, .mcpControls, "Named MCP servers from .mcp.json to approve.", mergeHint: .appendUnique),
        definition("disabledMcpjsonServers", .stringArray, .mcpControls, "Named MCP servers from .mcp.json to reject.", mergeHint: .appendUnique),
        definition("sandbox", .object(properties: [
            "enabled": .bool,
            "failIfUnavailable": .bool,
            "autoAllowBashIfSandboxed": .bool,
            "excludedCommands": .stringArray,
            "allowUnsandboxedCommands": .bool,
            "enableWeakerNestedSandbox": .bool,
            "enableWeakerNetworkIsolation": .bool,
            "filesystem": .object(properties: [
                "allowWrite": .stringArray,
                "denyWrite": .stringArray,
                "denyRead": .stringArray,
                "allowRead": .stringArray,
                "allowManagedReadPathsOnly": .bool
            ], allowAdditionalProperties: true),
            "network": .object(properties: [
                "allowUnixSockets": .stringArray,
                "allowAllUnixSockets": .bool,
                "allowLocalBinding": .bool,
                "allowedDomains": .stringArray,
                "allowManagedDomainsOnly": .bool,
                "httpProxyPort": .integer,
                "socksProxyPort": .integer
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true), .sandbox, "Sandbox policy family.", mergeHint: .deepMergeObject),
        definition("sandbox.enabled", .bool, .sandbox, "Enables sandboxing for command execution."),
        definition("sandbox.failIfUnavailable", .bool, .sandbox, "Fails commands if sandboxing is unavailable."),
        definition("sandbox.autoAllowBashIfSandboxed", .bool, .sandbox, "Auto-approves bash commands when sandboxed."),
        definition("sandbox.excludedCommands", .stringArray, .sandbox, "Commands that bypass the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.allowUnsandboxedCommands", .bool, .sandbox, "Allows explicit unsandboxed command execution."),
        definition("sandbox.enableWeakerNestedSandbox", .bool, .sandbox, "Relaxes nested sandbox enforcement for compatibility."),
        definition("sandbox.enableWeakerNetworkIsolation", .bool, .sandbox, "Relaxes network isolation for compatibility."),
        definition("sandbox.filesystem", .object(properties: [
            "allowWrite": .stringArray,
            "denyWrite": .stringArray,
            "denyRead": .stringArray,
            "allowRead": .stringArray,
            "allowManagedReadPathsOnly": .bool
        ], allowAdditionalProperties: true), .sandbox, "Sandbox filesystem settings.", mergeHint: .deepMergeObject),
        definition("sandbox.filesystem.allowWrite", .stringArray, .sandbox, "Additional writable paths inside the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.filesystem.denyWrite", .stringArray, .sandbox, "Write-denied paths inside the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.filesystem.denyRead", .stringArray, .sandbox, "Read-denied paths inside the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.filesystem.allowRead", .stringArray, .sandbox, "Read allowlist overrides inside the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.filesystem.allowManagedReadPathsOnly", .bool, .sandbox, "Restricts sandbox read allowlists to managed sources.", isManagedOnly: true),
        definition("sandbox.network", .object(properties: [
            "allowUnixSockets": .stringArray,
            "allowAllUnixSockets": .bool,
            "allowLocalBinding": .bool,
            "allowedDomains": .stringArray,
            "allowManagedDomainsOnly": .bool,
            "httpProxyPort": .integer,
            "socksProxyPort": .integer
        ], allowAdditionalProperties: true), .sandbox, "Sandbox network settings.", mergeHint: .deepMergeObject),
        definition("sandbox.network.allowUnixSockets", .stringArray, .sandbox, "Unix socket paths allowed from the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.network.allowAllUnixSockets", .bool, .sandbox, "Allows all Unix sockets from the sandbox."),
        definition("sandbox.network.allowLocalBinding", .bool, .sandbox, "Allows binding to localhost from the sandbox."),
        definition("sandbox.network.allowedDomains", .stringArray, .sandbox, "Outbound domains allowed from the sandbox.", mergeHint: .appendUnique),
        definition("sandbox.network.allowManagedDomainsOnly", .bool, .sandbox, "Restricts sandbox domain allowlists to managed sources.", isManagedOnly: true),
        definition("sandbox.network.httpProxyPort", .integer, .sandbox, "HTTP proxy port for sandbox network routing."),
        definition("sandbox.network.socksProxyPort", .integer, .sandbox, "SOCKS proxy port for sandbox network routing."),
        definition("plugins", .dictionary(value: .object(properties: [:], allowAdditionalProperties: true)), .pluginsMarketplaces, "Plugin configuration family.", mergeHint: .deepMergeObject),
        definition("enabledPlugins", .dictionary(value: .bool), .pluginsMarketplaces, "Explicitly enabled plugin toggles keyed by plugin identifier.", mergeHint: .deepMergeObject),
        definition("disabledPlugins", .stringArray, .pluginsMarketplaces, "Explicitly disabled plugins.", mergeHint: .appendUnique),
        definition("extraKnownMarketplaces", .dictionary(value: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)), .pluginsMarketplaces, "Additional marketplace definitions keyed by marketplace identifier.", mergeHint: .deepMergeObject),
        definition("allowedChannelPlugins", .array(element: .object(properties: [
            "plugin": .string,
            "marketplace": .string,
            "channels": .stringArray
        ], allowAdditionalProperties: true)), .pluginsMarketplaces, "Plugins allowed in channel contexts.", isManagedOnly: true, mergeHint: .appendUnique),
        definition("channelsEnabled", .bool, .pluginsMarketplaces, "Enables channels.", isManagedOnly: true),
        definition("strictKnownMarketplaces", .array(element: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)), .pluginsMarketplaces, "Managed-only marketplace allowlist.", isManagedOnly: true, mergeHint: .appendUnique),
        definition("blockedMarketplaces", .array(element: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)), .pluginsMarketplaces, "Managed-only blocked marketplace list.", isManagedOnly: true, mergeHint: .appendUnique),
        definition("pluginTrustMessage", .string, .pluginsMarketplaces, "Managed-only message shown when plugins require trust.", isManagedOnly: true),
        definition("marketplaces", .array(element: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)), .pluginsMarketplaces, "Configured plugin marketplaces.", mergeHint: .appendUnique),
        definition("pluginConfigs", .dictionary(value: .object(properties: [:], allowAdditionalProperties: true)), .pluginsMarketplaces, "Per-plugin diagnostic configuration blobs.", mergeHint: .deepMergeObject, isAdvanced: true, isReadOnlyDiagnostic: true),
        definition("skippedPlugins", .stringArray, .pluginsMarketplaces, "Plugins dismissed by the user.", mergeHint: .appendUnique, isAdvanced: true, isReadOnlyDiagnostic: true),
        definition("skippedMarketplaces", .stringArray, .pluginsMarketplaces, "Marketplaces dismissed by the user.", mergeHint: .appendUnique, isAdvanced: true, isReadOnlyDiagnostic: true),
        definition("auth", .object(properties: [:], allowAdditionalProperties: true), .authenticationIdentity, "Authentication helper settings.", mergeHint: .deepMergeObject),
        definition("defaultShell", .string, .uiSessionExperience, "Default shell used for commands."),
        definition("autoMemoryDirectory", .string, .memoryClaudeMd, "Directory where auto-memory files are stored."),
        definition("autoMemoryEnabled", .bool, .memoryClaudeMd, "Enables auto-memory generation."),
        definition("claudeMdExcludes", .stringArray, .memoryClaudeMd, "Glob patterns excluded from CLAUDE.md ingestion.", mergeHint: .appendUnique),
        definition("memory", .object(properties: [:], allowAdditionalProperties: true), .memoryClaudeMd, "Memory-related settings.", mergeHint: .deepMergeObject),
        definition("statusLine", .object(properties: [
            "type": .string,
            "command": .string,
            "padding": .integer
        ], allowAdditionalProperties: true), .uiSessionExperience, "Status line integration settings.", mergeHint: .deepMergeObject),
        definition("fileSuggestion", .object(properties: [
            "type": .string,
            "command": .string
        ], allowAdditionalProperties: true), .uiSessionExperience, "File suggestion integration settings.", mergeHint: .deepMergeObject),
        definition("language", .string, .uiSessionExperience, "Preferred response language."),
        definition("respectGitignore", .bool, .uiSessionExperience, "Whether file suggestions should honor .gitignore."),
        definition("prefersReducedMotion", .bool, .uiSessionExperience, "Reduced motion preference."),
        definition("spinnerVerbs", .object(properties: [
            "mode": .string,
            "verbs": .stringArray
        ], allowAdditionalProperties: true), .uiSessionExperience, "Custom spinner verbs.", mergeHint: .deepMergeObject),
        definition("spinnerTipsEnabled", .bool, .uiSessionExperience, "Enables spinner tips."),
        definition("spinnerTipsOverride", .object(properties: [
            "excludeDefault": .bool,
            "tips": .stringArray
        ], allowAdditionalProperties: true), .uiSessionExperience, "Overrides default spinner tips.", mergeHint: .deepMergeObject),
        definition("outputStyle", .string, .uiSessionExperience, "Output style preference."),
        definition("voiceEnabled", .bool, .uiSessionExperience, "Enables voice dictation features."),
        definition("showClearContextOnPlanAccept", .bool, .uiSessionExperience, "Shows clear-context option when accepting a plan."),
        definition("worktree", .object(properties: [
            "sparsePaths": .stringArray,
            "symlinkDirectories": .stringArray
        ], allowAdditionalProperties: true), .worktree, "Worktree behavior settings.", mergeHint: .deepMergeObject),
        definition("worktree.sparsePaths", .stringArray, .worktree, "Sparse checkout paths.", mergeHint: .appendUnique),
        definition("worktree.symlinkDirectories", .stringArray, .worktree, "Directories to symlink into worktrees.", mergeHint: .appendUnique),
        definition("plansDirectory", .string, .operations, "Directory for saved plans."),
        definition("autoUpdatesChannel", .string, .operations, "Auto-update release channel."),
        definition("disableDeepLinkRegistration", .string, .operations, "Disables deep-link registration when set to \"disable\"."),
        definition("disableUpdateChecks", .bool, .operations, "Disables update checks.")
    ]

    static func definition(
        _ keyPath: String,
        _ type: SettingsKeyType,
        _ category: SettingsKeyCategory,
        _ description: String,
        isManagedOnly: Bool = false,
        applicableScopes: Set<ResolutionScope> = [.managed, .user, .project, .projectLocal],
        mergeHint: MergeMethod = .selectHighestPrecedence,
        isAdvanced: Bool = false,
        isReadOnlyDiagnostic: Bool = false
    ) -> SettingsKeyDefinition {
        SettingsKeyDefinition(
            keyPath: keyPath,
            type: type,
            category: category,
            description: description,
            isManagedOnly: isManagedOnly,
            applicableScopes: applicableScopes,
            mergeHint: mergeHint,
            isAdvanced: isAdvanced,
            isReadOnlyDiagnostic: isReadOnlyDiagnostic
        )
    }
}
