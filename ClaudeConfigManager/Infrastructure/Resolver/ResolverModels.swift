import Foundation

enum ResolutionScope: String, Equatable, Sendable {
    case managed
    case user
    case project
    case projectLocal
    case session
    case cli
    case imported
    case autoMemory
    case synthetic
}

enum ResolutionSourceKind: String, Equatable, Sendable {
    case managed
    case cli
    case file
    case imported
    case autoMemory
    case synthetic
}

enum ResolutionAvailability: String, Equatable, Sendable {
    case present
    case missing
    case invalid
    case inaccessible
}

struct ResolutionSource: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let scope: ResolutionScope
    let kind: ResolutionSourceKind
    let identifier: String
    let displayName: String?
    let sourcePath: String?
    let availability: ResolutionAvailability

    init(
        scope: ResolutionScope,
        kind: ResolutionSourceKind,
        identifier: String,
        displayName: String? = nil,
        sourcePath: String? = nil,
        availability: ResolutionAvailability = .present
    ) {
        self.scope = scope
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
        self.sourcePath = sourcePath
        self.availability = availability
        self.id = Self.makeID(scope: scope, kind: kind, identifier: identifier, sourcePath: sourcePath)
    }

    var isAvailable: Bool {
        availability == .present
    }

    private static func makeID(
        scope: ResolutionScope,
        kind: ResolutionSourceKind,
        identifier: String,
        sourcePath: String?
    ) -> String {
        let normalizedPath = sourcePath ?? "none"
        return "\(scope.rawValue)::\(kind.rawValue)::\(identifier)::\(normalizedPath)"
    }
}

enum MergeMethod: String, Equatable, Sendable {
    case selectHighestPrecedence
    case replace
    case deepMergeObject
    case append
    case appendUnique
    case setUnion
    case keyedByIdentifier
    case passthrough
}

struct ResolutionTrace: Equatable, Sendable {
    let participants: [ResolutionSource]
    let overridden: [ResolutionSource]
    let notes: [String]

    init(
        participants: [ResolutionSource],
        overridden: [ResolutionSource] = [],
        notes: [String] = []
    ) {
        self.participants = Self.deduplicated(participants)
        self.overridden = Self.deduplicated(overridden)
        self.notes = notes
    }

    private static func deduplicated(_ sources: [ResolutionSource]) -> [ResolutionSource] {
        var seen = Set<String>()
        var result: [ResolutionSource] = []

        for source in sources where seen.insert(source.id).inserted {
            result.append(source)
        }

        return result
    }
}

enum ResolutionIssueSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error
}

enum ResolutionIssueCode: String, Equatable, Sendable {
    case unresolvedValue
    case missingSource
    case invalidSource
    case inaccessibleSource
    case unsupportedShape
    case typeMismatch
    case duplicateIdentifier
    case conflict
    case cycleDetected
    case unresolvedImport
    case importDepthExceeded
    case parserSyntaxIssue
    case note
}

struct ResolutionIssue: Equatable, Identifiable, Sendable {
    let id: String
    let code: ResolutionIssueCode
    let severity: ResolutionIssueSeverity
    let message: String
    let source: ResolutionSource?
    let keyPath: String?
    let range: SourceRange?
    let underlyingParserCode: String?
    let relatedSources: [ResolutionSource]

    init(
        code: ResolutionIssueCode,
        severity: ResolutionIssueSeverity,
        message: String,
        source: ResolutionSource? = nil,
        keyPath: String? = nil,
        range: SourceRange? = nil,
        underlyingParserCode: String? = nil,
        relatedSources: [ResolutionSource] = []
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.source = source
        self.keyPath = keyPath
        self.range = range
        self.underlyingParserCode = underlyingParserCode
        self.relatedSources = Self.deduplicated(relatedSources)
        self.id = Self.makeID(
            code: code,
            source: source,
            keyPath: keyPath,
            underlyingParserCode: underlyingParserCode,
            message: message
        )
    }

    init(syntaxIssue: SyntaxIssue, source: ResolutionSource?) {
        self.init(
            code: Self.mapParserIssueCode(syntaxIssue.code),
            severity: Self.mapSeverity(syntaxIssue.severity),
            message: syntaxIssue.message,
            source: source,
            keyPath: syntaxIssue.keyPath,
            range: syntaxIssue.range,
            underlyingParserCode: syntaxIssue.code.rawValue,
            relatedSources: []
        )
    }

    private static func makeID(
        code: ResolutionIssueCode,
        source: ResolutionSource?,
        keyPath: String?,
        underlyingParserCode: String?,
        message: String
    ) -> String {
        "\(code.rawValue)-\(source?.id ?? "none")-\(keyPath ?? "root")-\(underlyingParserCode ?? "none")-\(message)"
    }

    private static func deduplicated(_ sources: [ResolutionSource]) -> [ResolutionSource] {
        var seen = Set<String>()
        var result: [ResolutionSource] = []

        for source in sources where seen.insert(source.id).inserted {
            result.append(source)
        }

        return result
    }

    private static func mapSeverity(_ severity: IssueSeverity) -> ResolutionIssueSeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func mapParserIssueCode(_ parserCode: SyntaxIssueCode) -> ResolutionIssueCode {
        switch parserCode {
        case .typeMismatch:
            return .typeMismatch
        case .invalidJSON,
             .topLevelNotObject,
             .ambiguousMcpTransport,
             .missingMcpTransport,
             .deprecatedMcpTransport,
             .invalidMcpRestrictionRule,
             .managedOnlySettingInNonManagedScope,
             .invalidHookShape,
             .preservedUnknownHookEvent,
             .invalidPermissionsShape,
             .invalidEnvShape,
             .invalidAttributionShape,
             .invalidClaudeJsonGlobalPreferencesShape,
             .invalidClaudeJsonMcpShape,
             .invalidTrustStateShape,
             .settingsFamilyKeyInClaudeJson,
             .claudeJsonOnlyKeyInSettings,
             .preservedUnsupportedKey,
             .invalidFrontmatterFence,
             .invalidYAMLFrontmatter,
             .frontmatterTopLevelNotObject,
             .missingSkillMarkdown,
             .invalidMarkdownReferenceToken,
             .preservedUnknownValue:
            return .parserSyntaxIssue
        }
    }
}

enum ValidationSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error

    var isBlocking: Bool {
        self == .error
    }

    init(_ issueSeverity: IssueSeverity) {
        switch issueSeverity {
        case .info:
            self = .info
        case .warning:
            self = .warning
        case .error:
            self = .error
        }
    }

    init(_ issueSeverity: ResolutionIssueSeverity) {
        switch issueSeverity {
        case .info:
            self = .info
        case .warning:
            self = .warning
        case .error:
            self = .error
        }
    }
}

enum ValidationCategory: String, Equatable, Sendable {
    case schema
    case semantic
    case parserSyntax
}

struct ValidationCode: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static func schema(_ key: String) -> ValidationCode {
        ValidationCode("schema.\(key)")
    }

    static func semantic(_ key: String) -> ValidationCode {
        ValidationCode("semantic.\(key)")
    }

    static func parser(_ key: String) -> ValidationCode {
        ValidationCode("parser.\(key)")
    }
}

enum ValidationSourceKind: String, Equatable, Sendable {
    case file
    case directory
    case virtual
}

struct ValidationSourceReference: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let kind: ValidationSourceKind
    let identifier: String
    let displayName: String?
    let sourcePath: String?
    let scope: ResolutionScope?

    init(
        kind: ValidationSourceKind,
        identifier: String,
        displayName: String? = nil,
        sourcePath: String? = nil,
        scope: ResolutionScope? = nil
    ) {
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
        self.sourcePath = sourcePath
        self.scope = scope
        self.id = Self.makeID(kind: kind, identifier: identifier, sourcePath: sourcePath, scope: scope)
    }

    init(sourcePath: String, kind: ValidationSourceKind = .file) {
        self.init(
            kind: kind,
            identifier: sourcePath,
            displayName: sourcePath,
            sourcePath: sourcePath
        )
    }

    init(virtualIdentifier: String, displayName: String? = nil) {
        self.init(
            kind: .virtual,
            identifier: virtualIdentifier,
            displayName: displayName
        )
    }

    init(resolutionSource: ResolutionSource) {
        let defaultKind: ValidationSourceKind = resolutionSource.sourcePath == nil ? .virtual : .file
        self.init(
            kind: defaultKind,
            identifier: resolutionSource.identifier,
            displayName: resolutionSource.displayName ?? resolutionSource.sourcePath ?? resolutionSource.identifier,
            sourcePath: resolutionSource.sourcePath,
            scope: resolutionSource.scope
        )
    }

    private static func makeID(
        kind: ValidationSourceKind,
        identifier: String,
        sourcePath: String?,
        scope: ResolutionScope?
    ) -> String {
        "\(kind.rawValue)::\(scope?.rawValue ?? "none")::\(identifier)::\(sourcePath ?? "none")"
    }
}

struct ValidationIssue: Equatable, Identifiable, Sendable {
    let id: String
    let code: ValidationCode
    let severity: ValidationSeverity
    let category: ValidationCategory
    let message: String
    let source: ValidationSourceReference?
    let keyPath: String?
    let range: SourceRange?
    let relatedSources: [ValidationSourceReference]
    let underlyingParserCode: String?
    let underlyingResolutionCode: String?

    init(
        code: ValidationCode,
        severity: ValidationSeverity,
        category: ValidationCategory,
        message: String,
        source: ValidationSourceReference? = nil,
        keyPath: String? = nil,
        range: SourceRange? = nil,
        relatedSources: [ValidationSourceReference] = [],
        underlyingParserCode: String? = nil,
        underlyingResolutionCode: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.category = category
        self.message = message
        self.source = source
        self.keyPath = keyPath
        self.range = range
        self.relatedSources = Self.deduplicated(relatedSources)
        self.underlyingParserCode = underlyingParserCode
        self.underlyingResolutionCode = underlyingResolutionCode
        self.id = Self.makeID(
            code: code,
            severity: severity,
            category: category,
            source: source,
            keyPath: keyPath,
            range: range,
            underlyingParserCode: underlyingParserCode,
            underlyingResolutionCode: underlyingResolutionCode,
            message: message
        )
    }

    init(syntaxIssue: SyntaxIssue, source: ValidationSourceReference? = nil) {
        self.init(
            code: .parser(syntaxIssue.code.rawValue),
            severity: ValidationSeverity(syntaxIssue.severity),
            category: .parserSyntax,
            message: syntaxIssue.message,
            source: source ?? ValidationSourceReference(sourcePath: syntaxIssue.sourcePath),
            keyPath: syntaxIssue.keyPath,
            range: syntaxIssue.range,
            relatedSources: [],
            underlyingParserCode: syntaxIssue.code.rawValue,
            underlyingResolutionCode: nil
        )
    }

    init(resolutionIssue: ResolutionIssue, category: ValidationCategory? = nil) {
        let resolvedCategory = category ?? Self.defaultCategory(for: resolutionIssue.code)
        self.init(
            code: Self.code(from: resolutionIssue, category: resolvedCategory),
            severity: ValidationSeverity(resolutionIssue.severity),
            category: resolvedCategory,
            message: resolutionIssue.message,
            source: resolutionIssue.source.map(ValidationSourceReference.init(resolutionSource:)),
            keyPath: resolutionIssue.keyPath,
            range: resolutionIssue.range,
            relatedSources: resolutionIssue.relatedSources.map(ValidationSourceReference.init(resolutionSource:)),
            underlyingParserCode: resolutionIssue.underlyingParserCode,
            underlyingResolutionCode: resolutionIssue.code.rawValue
        )
    }

    func asResolutionIssue() -> ResolutionIssue {
        ResolutionIssue(
            code: mappedResolutionCode,
            severity: mappedResolutionSeverity,
            message: message,
            source: source.map { source in
                ResolutionSource(
                    scope: source.scope ?? .synthetic,
                    kind: source.sourcePath == nil ? .synthetic : .file,
                    identifier: source.identifier,
                    displayName: source.displayName,
                    sourcePath: source.sourcePath,
                    availability: .present
                )
            },
            keyPath: keyPath,
            range: range,
            underlyingParserCode: underlyingParserCode,
            relatedSources: relatedSources.map { source in
                ResolutionSource(
                    scope: source.scope ?? .synthetic,
                    kind: source.sourcePath == nil ? .synthetic : .file,
                    identifier: source.identifier,
                    displayName: source.displayName,
                    sourcePath: source.sourcePath,
                    availability: .present
                )
            }
        )
    }

    private static func deduplicated(_ sources: [ValidationSourceReference]) -> [ValidationSourceReference] {
        var seen = Set<String>()
        return sources
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }

    private static func makeID(
        code: ValidationCode,
        severity: ValidationSeverity,
        category: ValidationCategory,
        source: ValidationSourceReference?,
        keyPath: String?,
        range: SourceRange?,
        underlyingParserCode: String?,
        underlyingResolutionCode: String?,
        message: String
    ) -> String {
        let rangeID: String
        if let range {
            rangeID = "\(range.startLine):\(range.startColumn)-\(range.endLine):\(range.endColumn)"
        } else {
            rangeID = "none"
        }
        return "\(category.rawValue)::\(code.rawValue)::\(severity.rawValue)::\(source?.id ?? "none")::\(keyPath ?? "root")::\(rangeID)::\(underlyingParserCode ?? "none")::\(underlyingResolutionCode ?? "none")::\(message)"
    }

    private static func defaultCategory(for code: ResolutionIssueCode) -> ValidationCategory {
        switch code {
        case .parserSyntaxIssue:
            return .parserSyntax
        default:
            return .semantic
        }
    }

    private static func code(from resolutionIssue: ResolutionIssue, category: ValidationCategory) -> ValidationCode {
        if let parserCode = resolutionIssue.underlyingParserCode {
            return .parser(parserCode)
        }

        switch category {
        case .schema:
            return .schema(resolutionIssue.code.rawValue)
        case .semantic:
            return .semantic(resolutionIssue.code.rawValue)
        case .parserSyntax:
            return .parser(resolutionIssue.code.rawValue)
        }
    }

    private var mappedResolutionCode: ResolutionIssueCode {
        if let underlyingResolutionCode,
           let code = ResolutionIssueCode(rawValue: underlyingResolutionCode) {
            return code
        }

        if let parserCode = underlyingParserCode {
            if parserCode == SyntaxIssueCode.typeMismatch.rawValue {
                return .typeMismatch
            }
            return .parserSyntaxIssue
        }

        if code.rawValue.contains("typeMismatch") {
            return .typeMismatch
        }

        switch category {
        case .schema:
            return .unsupportedShape
        case .semantic:
            return .conflict
        case .parserSyntax:
            return .parserSyntaxIssue
        }
    }

    private var mappedResolutionSeverity: ResolutionIssueSeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

struct ValidationSummary: Equatable, Sendable {
    let totalIssues: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let blockingCount: Int
    let hasBlockingIssues: Bool
}

struct ValidationResult: Equatable, Sendable {
    let issues: [ValidationIssue]

    init(issues: [ValidationIssue] = []) {
        self.issues = Self.stableIssues(issues)
    }

    var summary: ValidationSummary {
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        return ValidationSummary(
            totalIssues: issues.count,
            errorCount: errorCount,
            warningCount: warningCount,
            infoCount: infoCount,
            blockingCount: errorCount,
            hasBlockingIssues: errorCount > 0
        )
    }

    var hasErrors: Bool {
        summary.errorCount > 0
    }

    var hasBlockingIssues: Bool {
        summary.hasBlockingIssues
    }

    func merging(_ other: ValidationResult) -> ValidationResult {
        ValidationResult(issues: issues + other.issues)
    }

    static func combined(_ results: [ValidationResult]) -> ValidationResult {
        let allIssues = results.flatMap(\.issues)
        return ValidationResult(issues: allIssues)
    }

    private static func stableIssues(_ issues: [ValidationIssue]) -> [ValidationIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct SchemaValidationContext: Equatable, Sendable {
    let family: String
    let source: ValidationSourceReference?

    init(family: String, source: ValidationSourceReference?) {
        self.family = family
        self.source = source
    }
}

struct SemanticValidationContext: Equatable, Sendable {
    let instructions: ResolvedInstructionSnapshot?
    let mcp: ResolvedMcpSnapshot?
    let agents: ResolvedAgentSnapshot?
    let skills: ResolvedSkillSnapshot?
    let existingIssues: [ValidationIssue]

    init(
        instructions: ResolvedInstructionSnapshot? = nil,
        mcp: ResolvedMcpSnapshot? = nil,
        agents: ResolvedAgentSnapshot? = nil,
        skills: ResolvedSkillSnapshot? = nil,
        existingIssues: [ValidationIssue] = []
    ) {
        self.instructions = instructions
        self.mcp = mcp
        self.agents = agents
        self.skills = skills
        self.existingIssues = existingIssues.sorted { $0.id < $1.id }
    }
}

struct SemanticRule {
    let key: String
    let evaluate: (SemanticValidationContext) -> [ValidationIssue]
}

struct SemanticValidator {
    private let rules: [SemanticRule]

    init(rules: [SemanticRule] = SemanticValidator.defaultRules) {
        self.rules = rules.sorted { $0.key < $1.key }
    }

    func validate(context: SemanticValidationContext) -> ValidationResult {
        let parserSyntaxIssueIDs = Set(
            context.existingIssues
                .filter { $0.category == .parserSyntax }
                .map(\.id)
        )

        var issues: [ValidationIssue] = []
        for rule in rules {
            let ruleIssues = rule.evaluate(context)
                .filter { parserSyntaxIssueIDs.contains($0.id) == false }
            issues.append(contentsOf: ruleIssues)
        }

        return ValidationResult(issues: issues)
    }

    private static let defaultRules: [SemanticRule] = [
        SemanticRule(key: "agents.duplicateIdentity", evaluate: validateAgentIdentityConflicts),
        SemanticRule(key: "instructions.importResolution", evaluate: validateInstructionImportSemantics),
        SemanticRule(key: "mcp.crossScope", evaluate: validateMcpCrossScopeAssumptions),
        SemanticRule(key: "mcp.environmentReferences", evaluate: validateMcpEnvironmentReferences),
        SemanticRule(key: "skills.duplicateIdentity", evaluate: validateSkillIdentityConflicts)
    ]

    private static func validateAgentIdentityConflicts(_ context: SemanticValidationContext) -> [ValidationIssue] {
        guard let agents = context.agents else { return [] }

        let resolverIssues = collectResolutionIssues(
            rootIssues: agents.issues,
            nestedIssues: agents.agents.flatMap { entry in
                entry.definition.issues + entry.visibility.issues + entry.isVisible.issues
            }
        )

        var issues = semanticIssues(
            from: resolverIssues,
            matchingCodes: [.duplicateIdentifier],
            containingMessage: "agent identity"
        )

        for entry in agents.agents where entry.visibility.effectiveValue == .overridden {
            guard let winner = entry.visibility.winningSource else { continue }
            issues.append(
                ValidationIssue(
                    code: .semantic("agent.overriddenByHigherPrecedence"),
                    severity: .warning,
                    category: .semantic,
                    message: "Agent identity '\(entry.agentID)' was overridden by higher-precedence source '\(winner.identifier)'.",
                    source: ValidationSourceReference(resolutionSource: entry.source),
                    keyPath: entry.agentID,
                    relatedSources: [ValidationSourceReference(resolutionSource: winner)]
                )
            )
        }

        return issues
    }

    private static func validateSkillIdentityConflicts(_ context: SemanticValidationContext) -> [ValidationIssue] {
        guard let skills = context.skills else { return [] }

        let resolverIssues = collectResolutionIssues(
            rootIssues: skills.issues,
            nestedIssues: skills.skills.flatMap { entry in
                entry.definition.issues + entry.visibility.issues + entry.isVisible.issues
            }
        )

        var issues = semanticIssues(
            from: resolverIssues,
            matchingCodes: [.duplicateIdentifier],
            containingMessage: "skill identity"
        )

        for entry in skills.skills where entry.visibility.effectiveValue == .overridden {
            guard let winner = entry.visibility.winningSource else { continue }
            issues.append(
                ValidationIssue(
                    code: .semantic("skill.overriddenByHigherPrecedence"),
                    severity: .warning,
                    category: .semantic,
                    message: "Skill identity '\(entry.skillID)' was overridden by higher-precedence source '\(winner.identifier)'.",
                    source: ValidationSourceReference(resolutionSource: entry.source),
                    keyPath: entry.skillID,
                    relatedSources: [ValidationSourceReference(resolutionSource: winner)]
                )
            )
        }

        return issues
    }

    private static func validateInstructionImportSemantics(_ context: SemanticValidationContext) -> [ValidationIssue] {
        guard let instructions = context.instructions else { return [] }

        let resolverIssues = collectResolutionIssues(
            rootIssues: instructions.issues,
            nestedIssues: instructions.orderedBlocks.flatMap(\.content.issues) + instructions.composedInstructions.issues
        )

        var issues = semanticIssues(
            from: resolverIssues,
            matchingCodes: [.unresolvedImport, .cycleDetected, .importDepthExceeded]
        )

        let sourceByBlockID = Dictionary(uniqueKeysWithValues: instructions.orderedBlocks.map { block in
            (block.blockID, block.content.winningSource)
        })

        for edge in instructions.importEdges where edge.childBlockID == nil && edge.isCycle == false {
            guard let parentSource = sourceByBlockID[edge.parentBlockID] ?? nil else { continue }
            let relatedSources = instructions.rootLoadOrder
                .filter { $0.id != parentSource.id }
                .map(ValidationSourceReference.init(resolutionSource:))

            issues.append(
                ValidationIssue(
                    code: .semantic("instruction.importUnreachable"),
                    severity: .warning,
                    category: .semantic,
                    message: "Instruction import '\(edge.rawToken)' could not be resolved to a reachable document.",
                    source: ValidationSourceReference(resolutionSource: parentSource),
                    keyPath: edge.parentBlockID,
                    range: edge.tokenRange,
                    relatedSources: relatedSources
                )
            )
        }

        return issues
    }

    private static func validateMcpCrossScopeAssumptions(_ context: SemanticValidationContext) -> [ValidationIssue] {
        guard let mcp = context.mcp else { return [] }
        var issues: [ValidationIssue] = []

        let resolverIssues = collectResolutionIssues(
            rootIssues: mcp.issues,
            nestedIssues: mcp.servers.flatMap(\.resolvedConfig.issues)
        )
        issues.append(
            contentsOf: semanticIssues(
                from: resolverIssues,
                matchingCodes: [.duplicateIdentifier, .unresolvedValue, .conflict]
            )
        )

        for entry in mcp.servers {
            let participants = entry.resolvedConfig.trace.participants
            let scopes = Set(participants.map(\.scope))
            if scopes.count > 1 {
                let source = entry.resolvedConfig.winningSource ?? participants.first
                let related = participants
                    .filter { $0.id != source?.id }
                    .map(ValidationSourceReference.init(resolutionSource:))
                issues.append(
                    ValidationIssue(
                        code: .semantic("mcp.crossScopeConflict"),
                        severity: .warning,
                        category: .semantic,
                        message: "MCP server '\(entry.serverID)' has competing definitions across scopes; precedence selected one effective source.",
                        source: source.map(ValidationSourceReference.init(resolutionSource:)),
                        keyPath: entry.serverID,
                        relatedSources: related
                    )
                )
            }
        }

        let fallbackIssues = resolverIssues.filter { issue in
            issue.code == .invalidSource &&
                issue.message.localizedCaseInsensitiveContains("fell back")
        }
        issues.append(
            contentsOf: fallbackIssues.map { issue in
                ValidationIssue(
                    code: .semantic("mcp.higherPrecedenceFallback"),
                    severity: .warning,
                    category: .semantic,
                    message: issue.message,
                    source: issue.source.map(ValidationSourceReference.init(resolutionSource:)),
                    keyPath: issue.keyPath,
                    range: issue.range,
                    relatedSources: issue.relatedSources.map(ValidationSourceReference.init(resolutionSource:))
                )
            }
        )

        return issues
    }

    private static func validateMcpEnvironmentReferences(_ context: SemanticValidationContext) -> [ValidationIssue] {
        guard let mcp = context.mcp else { return [] }
        var issues: [ValidationIssue] = []

        for entry in mcp.servers {
            for note in entry.environmentNotes {
                let source = entry.resolvedConfig.winningSource.map(ValidationSourceReference.init(resolutionSource:))
                switch note.classification {
                case .containsReference:
                    issues.append(
                        ValidationIssue(
                            code: .semantic("mcp.environmentReference"),
                            severity: .info,
                            category: .semantic,
                            message: "MCP server '\(entry.serverID)' includes environment-dependent value at '\(note.fieldPath)'.",
                            source: source,
                            keyPath: "\(entry.serverID).\(note.fieldPath)"
                        )
                    )
                case .unresolvedReference:
                    issues.append(
                        ValidationIssue(
                            code: .semantic("mcp.environmentReferenceUnresolved"),
                            severity: .warning,
                            category: .semantic,
                            message: "MCP server '\(entry.serverID)' has unresolved environment reference syntax at '\(note.fieldPath)'.",
                            source: source,
                            keyPath: "\(entry.serverID).\(note.fieldPath)"
                        )
                    )
                case .staticLiteral:
                    continue
                }
            }
        }

        return issues
    }

    private static func collectResolutionIssues(
        rootIssues: [ResolutionIssue],
        nestedIssues: [ResolutionIssue]
    ) -> [ResolutionIssue] {
        var seen = Set<String>()
        return (rootIssues + nestedIssues)
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }

    private static func semanticIssues(
        from issues: [ResolutionIssue],
        matchingCodes: [ResolutionIssueCode],
        containingMessage: String? = nil
    ) -> [ValidationIssue] {
        issues.compactMap { issue in
            guard matchingCodes.contains(issue.code) else { return nil }
            if let containingMessage,
               issue.message.localizedCaseInsensitiveContains(containingMessage) == false {
                return nil
            }
            guard issue.code != .parserSyntaxIssue else { return nil }
            return ValidationIssue(resolutionIssue: issue, category: .semantic)
        }
    }
}

struct SchemaValidator {
    func validate(settings document: ParsedSettingsDocument) -> ValidationResult {
        let context = SchemaValidationContext(
            family: "settings",
            source: ValidationSourceReference(sourcePath: document.source.displayPath)
        )
        var issues: [ValidationIssue] = []

        if document.value.autoMode == true, document.value.disableAutoMode == true {
            issues.append(
                makeIssue(
                    code: .schema("settings.autoModeConflict"),
                    severity: .error,
                    message: "'autoMode' and 'disableAutoMode' cannot both be true.",
                    context: context,
                    keyPath: "autoMode"
                )
            )
        }

        if let permissions = document.value.permissions {
            if permissions.mode != nil, permissions.allow != nil || permissions.deny != nil {
                issues.append(
                    makeIssue(
                        code: .schema("settings.permissionsModeWithAllowDeny"),
                        severity: .warning,
                        message: "permissions.mode should not be combined with permissions.allow or permissions.deny.",
                        context: context,
                        keyPath: "permissions.mode"
                    )
                )
            }

            let allowSet = Set(permissions.allow ?? [])
            let denySet = Set(permissions.deny ?? [])
            let overlap = allowSet.intersection(denySet).sorted()
            if !overlap.isEmpty {
                issues.append(
                    makeIssue(
                        code: .schema("settings.permissionsAllowDenyOverlap"),
                        severity: .warning,
                        message: "permissions.allow and permissions.deny overlap: \(overlap.joined(separator: ", ")).",
                        context: context,
                        keyPath: "permissions"
                    )
                )
            }
        }

        if let hooks = document.value.hooks {
            for event in hooks.events.values.sorted(by: { $0.eventName < $1.eventName }) {
                let eventPath = "hooks.\(event.eventName)"

                if event.actions.isEmpty {
                    issues.append(
                        makeIssue(
                            code: .schema("settings.hookEventMissingActions"),
                            severity: .error,
                            message: "Hook event must contain at least one action.",
                            context: context,
                            keyPath: eventPath
                        )
                    )
                }

                for (index, action) in event.actions.enumerated() {
                    let actionPath = "\(eventPath).actions[\(index)]"
                    let hasCommand = isNonEmpty(action.command)
                    let hasURL = isNonEmpty(action.url)

                    if hasCommand == hasURL {
                        issues.append(
                            makeIssue(
                                code: .schema("settings.hookActionTransportShape"),
                                severity: .error,
                                message: "Hook action must define exactly one of command or url.",
                                context: context,
                                keyPath: actionPath
                            )
                        )
                    }

                    if let type = action.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !type.isEmpty {
                        if type == "command", !hasCommand {
                            issues.append(
                                makeIssue(
                                    code: .schema("settings.hookActionTypeMismatch"),
                                    severity: .error,
                                    message: "Hook action type 'command' requires a command value.",
                                    context: context,
                                    keyPath: "\(actionPath).type"
                                )
                            )
                        } else if type == "http", !hasURL {
                            issues.append(
                                makeIssue(
                                    code: .schema("settings.hookActionTypeMismatch"),
                                    severity: .error,
                                    message: "Hook action type 'http' requires a url value.",
                                    context: context,
                                    keyPath: "\(actionPath).type"
                                )
                            )
                        }
                    }

                    if let timeout = action.timeout, timeout < 0 {
                        issues.append(
                            makeIssue(
                                code: .schema("settings.hookActionNegativeTimeout"),
                                severity: .error,
                                message: "Hook action timeout must be non-negative.",
                                context: context,
                                keyPath: "\(actionPath).timeout"
                            )
                        )
                    }
                }
            }
        }

        return ValidationResult(issues: issues)
    }

    func validate(claudeJson document: ParsedClaudeJsonDocument) -> ValidationResult {
        let context = SchemaValidationContext(
            family: "claudeJson",
            source: ValidationSourceReference(sourcePath: document.source.displayPath)
        )
        var issues: [ValidationIssue] = []

        if let mode = document.value.globalPreferences?.defaultMode?.trimmingCharacters(in: .whitespacesAndNewlines),
           mode.isEmpty {
            issues.append(
                makeIssue(
                    code: .schema("claudeJson.defaultModeEmpty"),
                    severity: .error,
                    message: "globalPreferences.defaultMode cannot be an empty string.",
                    context: context,
                    keyPath: "globalPreferences.defaultMode"
                )
            )
        }

        if let model = document.value.globalPreferences?.defaultModel?.trimmingCharacters(in: .whitespacesAndNewlines),
           model.isEmpty {
            issues.append(
                makeIssue(
                    code: .schema("claudeJson.defaultModelEmpty"),
                    severity: .error,
                    message: "globalPreferences.defaultModel cannot be an empty string.",
                    context: context,
                    keyPath: "globalPreferences.defaultModel"
                )
            )
        }

        if let mcp = document.value.mcpState {
            let overlappingIDs = Set(mcp.userServers.keys).intersection(Set(mcp.localServers.keys)).sorted()
            for serverID in overlappingIDs {
                issues.append(
                    makeIssue(
                        code: .schema("claudeJson.mcpDuplicateAcrossScopes"),
                        severity: .warning,
                        message: "MCP server '\(serverID)' is defined in both mcp.user and mcp.local.",
                        context: context,
                        keyPath: "mcp.\(serverID)"
                    )
                )
            }

            for serverID in mcp.userServers.keys.sorted() {
                guard let server = mcp.userServers[serverID] else { continue }
                issues.append(
                    contentsOf: validateClaudeMcpServer(
                        server,
                        keyPath: "mcp.user.\(serverID)",
                        context: context
                    )
                )
            }

            for serverID in mcp.localServers.keys.sorted() {
                guard let server = mcp.localServers[serverID] else { continue }
                issues.append(
                    contentsOf: validateClaudeMcpServer(
                        server,
                        keyPath: "mcp.local.\(serverID)",
                        context: context
                    )
                )
            }
        }

        if let trustState = document.value.trustState {
            let overlap = Set(trustState.trustedProjectPaths)
                .intersection(Set(trustState.blockedProjectPaths))
                .sorted()
            if !overlap.isEmpty {
                issues.append(
                    makeIssue(
                        code: .schema("claudeJson.trustPathOverlap"),
                        severity: .warning,
                        message: "trust.trustedProjectPaths and trust.blockedProjectPaths overlap: \(overlap.joined(separator: ", ")).",
                        context: context,
                        keyPath: "trust"
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    func validate(claudeMd document: ParsedClaudeMdDocument) -> ValidationResult {
        let context = SchemaValidationContext(
            family: "claudeMd",
            source: ValidationSourceReference(sourcePath: document.source.displayPath)
        )
        var issues: [ValidationIssue] = []

        if document.rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                makeIssue(
                    code: .schema("claudeMd.emptyBody"),
                    severity: .warning,
                    message: "Instruction markdown body is empty.",
                    context: context
                )
            )
        }

        let validImports = document.imports.enumerated().filter { $0.element.status == .valid }
        for (index, token) in validImports {
            let path = token.rawPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if path == "." || path == ".." {
                issues.append(
                    makeIssue(
                        code: .schema("claudeMd.importPathInvalid"),
                        severity: .error,
                        message: "Import token path must not be '.' or '..'.",
                        context: context,
                        keyPath: "imports[\(index)]",
                        range: token.range
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    func validate(agent document: ParsedAgentDocument) -> ValidationResult {
        let context = SchemaValidationContext(
            family: "agent",
            source: ValidationSourceReference(sourcePath: document.source.displayPath)
        )
        var issues: [ValidationIssue] = []

        guard let frontmatter = document.frontmatter else {
            issues.append(
                makeIssue(
                    code: .schema("agent.frontmatterMissing"),
                    severity: .error,
                    message: "Agent file must include YAML frontmatter.",
                    context: context
                )
            )
            return ValidationResult(issues: issues)
        }

        if !isNonEmpty(frontmatter.name) {
            issues.append(
                makeIssue(
                    code: .schema("agent.nameMissing"),
                    severity: .error,
                    message: "Agent frontmatter requires a non-empty name.",
                    context: context,
                    keyPath: "name"
                )
            )
        }

        if !isNonEmpty(frontmatter.description) {
            issues.append(
                makeIssue(
                    code: .schema("agent.descriptionMissing"),
                    severity: .error,
                    message: "Agent frontmatter requires a non-empty description.",
                    context: context,
                    keyPath: "description"
                )
            )
        }

        var seenTools = Set<String>()
        for (index, tool) in frontmatter.tools.enumerated() {
            let trimmed = tool.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyPath = "tools[\(index)]"

            if trimmed.isEmpty {
                issues.append(
                    makeIssue(
                        code: .schema("agent.toolEmpty"),
                        severity: .error,
                        message: "Agent tool entries must be non-empty strings.",
                        context: context,
                        keyPath: keyPath
                    )
                )
                continue
            }

            let normalized = trimmed.lowercased()
            if !seenTools.insert(normalized).inserted {
                issues.append(
                    makeIssue(
                        code: .schema("agent.toolDuplicate"),
                        severity: .warning,
                        message: "Duplicate agent tool entry '\(trimmed)'.",
                        context: context,
                        keyPath: keyPath
                    )
                )
            }
        }

        if document.promptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                makeIssue(
                    code: .schema("agent.promptBodyEmpty"),
                    severity: .error,
                    message: "Agent prompt body must not be empty.",
                    context: context
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    func validate(skill document: ParsedSkillDocument) -> ValidationResult {
        let context = SchemaValidationContext(
            family: "skill",
            source: ValidationSourceReference(sourcePath: document.directory.skillMarkdownURL.path)
        )
        var issues: [ValidationIssue] = []

        if !document.directory.hasSkillMarkdown {
            issues.append(
                makeIssue(
                    code: .schema("skill.skillMarkdownMissing"),
                    severity: .error,
                    message: "Skill directory must include SKILL.md.",
                    context: context
                )
            )
            return ValidationResult(issues: issues)
        }

        if document.body?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            issues.append(
                makeIssue(
                    code: .schema("skill.bodyEmpty"),
                    severity: .warning,
                    message: "Skill body is empty.",
                    context: context
                )
            )
        }

        if let frontmatter = document.frontmatter {
            if !isNonEmpty(frontmatter.name) {
                issues.append(
                    makeIssue(
                        code: .schema("skill.nameMissing"),
                        severity: .warning,
                        message: "Skill frontmatter should include a non-empty name.",
                        context: context,
                        keyPath: "name"
                    )
                )
            }

            if !isNonEmpty(frontmatter.description) {
                issues.append(
                    makeIssue(
                        code: .schema("skill.descriptionMissing"),
                        severity: .warning,
                        message: "Skill frontmatter should include a non-empty description.",
                        context: context,
                        keyPath: "description"
                    )
                )
            }

            if let tags = frontmatter.tags {
                var seenTags = Set<String>()
                for (index, tag) in tags.enumerated() {
                    let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                    let keyPath = "tags[\(index)]"
                    if trimmed.isEmpty {
                        issues.append(
                            makeIssue(
                                code: .schema("skill.tagEmpty"),
                                severity: .warning,
                                message: "Skill tags should not contain empty entries.",
                                context: context,
                                keyPath: keyPath
                            )
                        )
                        continue
                    }

                    let normalized = trimmed.lowercased()
                    if !seenTags.insert(normalized).inserted {
                        issues.append(
                            makeIssue(
                                code: .schema("skill.tagDuplicate"),
                                severity: .warning,
                                message: "Duplicate skill tag '\(trimmed)'.",
                                context: context,
                                keyPath: keyPath
                            )
                        )
                    }
                }
            }
        } else {
            issues.append(
                makeIssue(
                    code: .schema("skill.frontmatterMissing"),
                    severity: .warning,
                    message: "Skill file should include frontmatter metadata.",
                    context: context
                )
            )
        }

        for (index, reference) in document.supportingReferences.enumerated() where reference.isParseableLocalFileReference {
            if reference.normalizedPath == nil {
                issues.append(
                    makeIssue(
                        code: .schema("skill.referenceMissingPath"),
                        severity: .error,
                        message: "Supporting reference is missing a path.",
                        context: context,
                        keyPath: "supportingReferences[\(index)]"
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    func validate(mcpDocument document: McpDocumentCandidate) -> ValidationResult {
        let context = SchemaValidationContext(
            family: "mcp",
            source: document.source.sourcePath.map { ValidationSourceReference(sourcePath: $0, kind: .file) }
        )
        var issues: [ValidationIssue] = []

        if document.source.availability == .present, document.servers.isEmpty {
            issues.append(
                makeIssue(
                    code: .schema("mcp.serversMissing"),
                    severity: .warning,
                    message: "MCP document did not define any servers.",
                    context: context,
                    keyPath: "servers"
                )
            )
        }

        var duplicateCountByID: [String: Int] = [:]
        for server in document.servers {
            duplicateCountByID[server.serverID, default: 0] += 1
        }

        for serverID in duplicateCountByID.keys.sorted() where (duplicateCountByID[serverID] ?? 0) > 1 {
            issues.append(
                makeIssue(
                    code: .schema("mcp.serverDuplicate"),
                    severity: .warning,
                    message: "MCP server '\(serverID)' is declared multiple times in one document.",
                    context: context,
                    keyPath: "servers.\(serverID)"
                )
            )
        }

        for server in document.servers.sorted(by: mcpServerSort) {
            let serverPath = "servers.\(server.serverID)"
            guard let rawConfig = server.rawConfig else {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.serverConfigMissing"),
                        severity: .error,
                        message: "MCP server config is missing.",
                        context: context,
                        keyPath: serverPath
                    )
                )
                continue
            }

            guard case let .object(config) = rawConfig else {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.serverConfigNotObject"),
                        severity: .error,
                        message: "MCP server config must be an object.",
                        context: context,
                        keyPath: serverPath
                    )
                )
                continue
            }

            issues.append(contentsOf: validateMcpConfigObject(config, keyPath: serverPath, context: context))
        }

        return ValidationResult(issues: issues)
    }

    private func validateClaudeMcpServer(
        _ server: ParsedClaudeJsonMcpServerRef,
        keyPath: String,
        context: SchemaValidationContext
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        switch server.transportType {
        case .stdio:
            if !isNonEmpty(server.command) {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.serverTransportShape"),
                        severity: .error,
                        message: "MCP stdio server requires command to be set.",
                        context: context,
                        keyPath: keyPath
                    )
                )
            }
        case .http, .sse:
            if !isNonEmpty(server.url) {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.serverTransportShape"),
                        severity: .error,
                        message: "MCP URL-based server requires url to be set.",
                        context: context,
                        keyPath: keyPath
                    )
                )
            }
        case .plugin:
            if !isNonEmpty(server.pluginId) {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.serverTransportShape"),
                        severity: .error,
                        message: "Plugin-provided MCP server requires pluginId to be set.",
                        context: context,
                        keyPath: keyPath
                    )
                )
            }
        case .unknown:
            issues.append(
                makeIssue(
                    code: .schema("mcp.serverTransportShape"),
                    severity: .error,
                    message: "MCP server must define a supported transport.",
                    context: context,
                    keyPath: keyPath
                )
            )
        }

        if server.args != nil, server.transportType == .unknown {
            issues.append(
                makeIssue(
                    code: .schema("mcp.argsWithoutCommand"),
                    severity: .error,
                    message: "MCP server args requires command to be set.",
                    context: context,
                    keyPath: "\(keyPath).args"
                )
            )
        }

        if server.headers != nil, server.transportType == .unknown {
            issues.append(
                makeIssue(
                    code: .schema("mcp.headersWithoutUrl"),
                    severity: .error,
                    message: "MCP server headers requires url to be set.",
                    context: context,
                    keyPath: "\(keyPath).headers"
                )
            )
        }

        return issues
    }

    private func validateMcpConfigObject(
        _ config: [String: JSONValue],
        keyPath: String,
        context: SchemaValidationContext
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let command = config["command"].flatMap(extractNonEmptyString)
        let url = config["url"].flatMap(extractNonEmptyString)
        let hasCommand = command != nil
        let hasURL = url != nil

        if hasCommand == hasURL {
            issues.append(
                makeIssue(
                    code: .schema("mcp.serverTransportShape"),
                    severity: .error,
                    message: "MCP server must define exactly one of command or url.",
                    context: context,
                    keyPath: keyPath
                )
            )
        }

        if let args = config["args"] {
            guard case let .array(items) = args else {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.argsShapeInvalid"),
                        severity: .error,
                        message: "MCP args must be an array of strings.",
                        context: context,
                        keyPath: "\(keyPath).args"
                    )
                )
                return issues
            }

            if !hasCommand {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.argsWithoutCommand"),
                        severity: .error,
                        message: "MCP args requires command to be set.",
                        context: context,
                        keyPath: "\(keyPath).args"
                    )
                )
            }

            for (index, item) in items.enumerated() where extractString(item) == nil {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.argsShapeInvalid"),
                        severity: .error,
                        message: "MCP args must contain only string items.",
                        context: context,
                        keyPath: "\(keyPath).args[\(index)]"
                    )
                )
            }
        }

        if let env = config["env"] {
            issues.append(contentsOf: validateStringMap(env, keyPath: "\(keyPath).env", context: context))
        }

        if let headers = config["headers"] {
            if !hasURL {
                issues.append(
                    makeIssue(
                        code: .schema("mcp.headersWithoutUrl"),
                        severity: .error,
                        message: "MCP headers requires url to be set.",
                        context: context,
                        keyPath: "\(keyPath).headers"
                    )
                )
            }
            issues.append(contentsOf: validateStringMap(headers, keyPath: "\(keyPath).headers", context: context))
        }

        return issues
    }

    private func validateStringMap(
        _ value: JSONValue,
        keyPath: String,
        context: SchemaValidationContext
    ) -> [ValidationIssue] {
        guard case let .object(map) = value else {
            return [
                makeIssue(
                    code: .schema("mcp.stringMapInvalid"),
                    severity: .error,
                    message: "Field must be an object containing string values.",
                    context: context,
                    keyPath: keyPath
                )
            ]
        }

        var issues: [ValidationIssue] = []
        for key in map.keys.sorted() where extractString(map[key]!) == nil {
            issues.append(
                makeIssue(
                    code: .schema("mcp.stringMapInvalid"),
                    severity: .error,
                    message: "Expected string value.",
                    context: context,
                    keyPath: "\(keyPath).\(key)"
                )
            )
        }
        return issues
    }

    private func makeIssue(
        code: ValidationCode,
        severity: ValidationSeverity,
        message: String,
        context: SchemaValidationContext,
        keyPath: String? = nil,
        range: SourceRange? = nil
    ) -> ValidationIssue {
        ValidationIssue(
            code: code,
            severity: severity,
            category: .schema,
            message: message,
            source: context.source,
            keyPath: keyPath,
            range: range
        )
    }

    private func isNonEmpty(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func extractString(_ value: JSONValue) -> String? {
        guard case let .string(string) = value else { return nil }
        return string
    }

    private func extractNonEmptyString(_ value: JSONValue) -> String? {
        guard let string = extractString(value) else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mcpServerSort(lhs: McpDocumentServerEntry, rhs: McpDocumentServerEntry) -> Bool {
        if lhs.parseOrder != rhs.parseOrder {
            return lhs.parseOrder < rhs.parseOrder
        }
        return lhs.serverID < rhs.serverID
    }
}

struct ResolvedValue<Value: Equatable & Sendable>: Equatable, Sendable {
    let effectiveValue: Value?
    let winningSource: ResolutionSource?
    let trace: ResolutionTrace
    let mergeMethod: MergeMethod
    let issues: [ResolutionIssue]
    let notes: [String]

    init(
        effectiveValue: Value?,
        winningSource: ResolutionSource?,
        trace: ResolutionTrace,
        mergeMethod: MergeMethod,
        issues: [ResolutionIssue] = [],
        notes: [String] = []
    ) {
        self.effectiveValue = effectiveValue
        self.winningSource = winningSource
        self.trace = trace
        self.mergeMethod = mergeMethod
        self.issues = Self.stableIssues(issues)
        self.notes = notes
    }

    var isResolved: Bool {
        effectiveValue != nil
    }

    private static func stableIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted(by: { $0.id < $1.id })
            .filter { seen.insert($0.id).inserted }
    }
}

enum SettingsSourceTier: Int, Comparable, CaseIterable, Sendable {
    case managed = 0
    case cli = 1
    case projectLocal = 2
    case projectShared = 3
    case user = 4

    static func < (lhs: SettingsSourceTier, rhs: SettingsSourceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SettingsSourceCandidate: Equatable, Sendable {
    let tier: SettingsSourceTier
    let precedenceRank: Int
    let source: ResolutionSource
    let document: ParsedSettingsDocument?
    let issues: [ResolutionIssue]

    init(
        tier: SettingsSourceTier,
        precedenceRank: Int = 0,
        source: ResolutionSource,
        document: ParsedSettingsDocument?,
        issues: [ResolutionIssue] = []
    ) {
        self.tier = tier
        self.precedenceRank = precedenceRank
        self.source = source
        self.document = document
        self.issues = issues.sorted { $0.id < $1.id }
    }

    var normalizedTopLevelKeys: [String] {
        guard let document else { return [] }
        return document.rawTopLevelObject.keys.sorted()
    }

    func value(for keyPath: String) -> JSONValue? {
        document?.rawTopLevelObject[keyPath]
    }
}

struct SettingsSelectionEntry: Equatable, Sendable {
    let keyPath: String
    let winningSource: ResolutionSource?
    let winningValue: JSONValue?
    let participants: [ResolutionSource]
    let overridden: [ResolutionSource]
    let issues: [ResolutionIssue]
    let notes: [String]
}

struct ResolvedSettingsSourceSelection: Equatable, Sendable {
    let candidates: [SettingsSourceCandidate]
    let entries: [SettingsSelectionEntry]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(
        candidates: [SettingsSourceCandidate],
        entries: [SettingsSelectionEntry],
        issues: [ResolutionIssue] = [],
        notes: [String] = []
    ) {
        self.candidates = candidates
        self.entries = entries.sorted { $0.keyPath < $1.keyPath }
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

enum ManagedSettingsTierKind: String, Equatable, Sendable {
    case serverManaged
    case mdmPolicy
    case fileBased

    var displayName: String {
        switch self {
        case .serverManaged:
            return "Server-managed settings"
        case .mdmPolicy:
            return "MDM / OS policy"
        case .fileBased:
            return "File-based managed settings"
        }
    }
}

struct ManagedSettingsActiveTier: Equatable, Sendable {
    let kind: ManagedSettingsTierKind
    let sources: [ResolutionSource]
    let notes: [String]

    init(
        kind: ManagedSettingsTierKind,
        sources: [ResolutionSource],
        notes: [String] = []
    ) {
        self.kind = kind
        self.sources = ResolutionTrace(participants: sources).participants
        self.notes = notes
    }
}

struct ManagedSettingsResolution: Equatable, Sendable {
    let activeTier: ManagedSettingsActiveTier?
    let settingsCandidates: [SettingsSourceCandidate]
    let managedMcpDocuments: [McpDocumentCandidate]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(
        activeTier: ManagedSettingsActiveTier?,
        settingsCandidates: [SettingsSourceCandidate],
        managedMcpDocuments: [McpDocumentCandidate],
        issues: [ResolutionIssue] = [],
        notes: [String] = []
    ) {
        self.activeTier = activeTier
        self.settingsCandidates = settingsCandidates
        self.managedMcpDocuments = managedMcpDocuments
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

struct ManagedScopeStatusModel: Equatable, Sendable {
    let title: String
    let detail: String
    let activeTierLabel: String
    let sourceSummaries: [String]
    /// Describes whether the managed root path could be read, is genuinely absent, or was
    /// blocked by sandbox policy. Views use this to show an explicit fallback banner rather than
    /// silently treating inaccessible managed paths as "no policy".
    let accessOutcome: ManagedAccessOutcome

    /// Convenience initialiser for backward-compatible call sites that do not yet supply an
    /// access outcome. Defaults to `.missing` (no managed config deployed).
    init(resolution: ManagedSettingsResolution?) {
        self.init(resolution: resolution, accessOutcome: .missing)
    }

    /// Designated initialiser. `accessOutcome` describes how the managed path probe went
    /// regardless of whether any resolution was produced.
    init(resolution: ManagedSettingsResolution?, accessOutcome: ManagedAccessOutcome) {
        self.accessOutcome = accessOutcome

        if let activeTier = resolution?.activeTier {
            self.title = "Active managed tier"
            self.detail = activeTier.kind.displayName
            self.activeTierLabel = activeTier.kind.rawValue
            self.sourceSummaries = activeTier.sources.map {
                $0.displayName ?? $0.sourcePath ?? $0.identifier
            }
        } else {
            self.title = "No managed tier active"
            self.detail = "No server-managed settings, MDM policy, or file-based managed settings are currently active."
            self.activeTierLabel = "none"
            self.sourceSummaries = []
        }
    }
}

struct ManagedSettingsResolver {
    struct Input: Equatable, Sendable {
        let serverManagedSettings: SettingsSourceCandidate?
        let mdmManagedSettings: SettingsSourceCandidate?
        let fileBasedSettings: [SettingsSourceCandidate]
        let fileBasedManagedMcp: McpDocumentCandidate?

        init(
            serverManagedSettings: SettingsSourceCandidate? = nil,
            mdmManagedSettings: SettingsSourceCandidate? = nil,
            fileBasedSettings: [SettingsSourceCandidate] = [],
            fileBasedManagedMcp: McpDocumentCandidate? = nil
        ) {
            self.serverManagedSettings = serverManagedSettings
            self.mdmManagedSettings = mdmManagedSettings
            self.fileBasedSettings = fileBasedSettings
            self.fileBasedManagedMcp = fileBasedManagedMcp
        }
    }

    func resolve(input: Input) -> ManagedSettingsResolution {
        if let serverManaged = input.serverManagedSettings, isManagedTierPresent(serverManaged) {
            return ManagedSettingsResolution(
                activeTier: ManagedSettingsActiveTier(
                    kind: .serverManaged,
                    sources: [serverManaged.source],
                    notes: ["Server-managed settings are active and suppress lower managed tiers."]
                ),
                settingsCandidates: [serverManaged],
                managedMcpDocuments: [],
                issues: serverManaged.issues,
                notes: [
                    "Server-managed settings are active.",
                    "MDM / OS policy and file-based managed settings were suppressed."
                ]
            )
        }

        if let mdmManaged = input.mdmManagedSettings, isManagedTierPresent(mdmManaged) {
            return ManagedSettingsResolution(
                activeTier: ManagedSettingsActiveTier(
                    kind: .mdmPolicy,
                    sources: [mdmManaged.source],
                    notes: ["MDM / OS policy is active and suppresses file-based managed settings."]
                ),
                settingsCandidates: [mdmManaged],
                managedMcpDocuments: [],
                issues: mdmManaged.issues,
                notes: [
                    "MDM / OS policy is active.",
                    "File-based managed settings were suppressed because a higher managed tier is active."
                ]
            )
        }

        let fileBasedCandidates = activeFileBasedCandidates(from: input.fileBasedSettings)
        if !fileBasedCandidates.isEmpty {
            let activeTier = ManagedSettingsActiveTier(
                kind: .fileBased,
                sources: fileBasedCandidates.map(\.source),
                notes: ["File-based managed settings merge internally in deterministic order."]
            )

            var issues = fileBasedCandidates.flatMap(\.issues)
            if let managedMcp = input.fileBasedManagedMcp {
                issues.append(contentsOf: managedMcp.issues)
            }

            return ManagedSettingsResolution(
                activeTier: activeTier,
                settingsCandidates: fileBasedCandidates,
                managedMcpDocuments: input.fileBasedManagedMcp.map { [$0] } ?? [],
                issues: deduplicatedIssues(issues),
                notes: [
                    "File-based managed settings are active.",
                    "managed-settings.json loads before managed-settings.d/*.json.",
                    "Drop-in fragments are ordered lexicographically by path, and later fragments take precedence."
                ]
            )
        }

        return ManagedSettingsResolution(
            activeTier: nil,
            settingsCandidates: [],
            managedMcpDocuments: [],
            notes: ["No managed settings tier is active."]
        )
    }

    private func isManagedTierPresent(_ candidate: SettingsSourceCandidate) -> Bool {
        candidate.source.availability != .missing
    }

    private func activeFileBasedCandidates(from candidates: [SettingsSourceCandidate]) -> [SettingsSourceCandidate] {
        let available = candidates.filter { isManagedTierPresent($0) }
        guard !available.isEmpty else {
            return []
        }

        let loadOrder = available.sorted(by: Self.fileBasedLoadOrder)
        let highPrecedenceFirst = Array(loadOrder.reversed())

        return highPrecedenceFirst.enumerated().map { index, candidate in
            SettingsSourceCandidate(
                tier: candidate.tier,
                precedenceRank: index,
                source: candidate.source,
                document: candidate.document,
                issues: candidate.issues
            )
        }
    }

    private static func fileBasedLoadOrder(lhs: SettingsSourceCandidate, rhs: SettingsSourceCandidate) -> Bool {
        let lhsPriority = fileBasedPathPriority(lhs.source.sourcePath)
        let rhsPriority = fileBasedPathPriority(rhs.source.sourcePath)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        let lhsPath = lhs.source.sourcePath ?? lhs.source.id
        let rhsPath = rhs.source.sourcePath ?? rhs.source.id
        return lhsPath.localizedStandardCompare(rhsPath) == .orderedAscending
    }

    private static func fileBasedPathPriority(_ path: String?) -> Int {
        guard let path else { return 2 }
        if path.hasSuffix("/managed-settings.json") {
            return 0
        }
        if path.contains("/managed-settings.d/") {
            return 1
        }
        return 2
    }

    private func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct SettingsResolver {
    private let registry: SettingsKeyRegistry

    init(registry: SettingsKeyRegistry = .shared) {
        self.registry = registry
    }

    func resolvePrecedence(candidates: [SettingsSourceCandidate]) -> ResolvedSettingsSourceSelection {
        let orderedCandidates = Self.sortCandidates(candidates)
        let allIssues = Self.collectCandidateIssues(orderedCandidates)

        var allKeys = Set<String>()
        for candidate in orderedCandidates where candidate.source.availability == .present {
            allKeys.formUnion(candidate.normalizedTopLevelKeys)
        }

        let entries = allKeys.sorted().map { keyPath in
            let participants = orderedCandidates.compactMap { candidate -> (SettingsSourceCandidate, JSONValue)? in
                guard candidate.source.availability == .present,
                      let value = candidate.value(for: keyPath) else {
                    return nil
                }
                return (candidate, value)
            }

            let winningPair = participants.first
            let participantSources = participants.map { $0.0.source }
            let overriddenSources = Array(participantSources.dropFirst())

            return SettingsSelectionEntry(
                keyPath: keyPath,
                winningSource: winningPair?.0.source,
                winningValue: winningPair?.1,
                participants: participantSources,
                overridden: overriddenSources,
                issues: [],
                notes: winningPair == nil ? ["No usable source provided this key."] : ["Selected highest-precedence available source."]
            )
        }

        return ResolvedSettingsSourceSelection(
            candidates: orderedCandidates,
            entries: entries,
            issues: allIssues,
            notes: ["Settings precedence resolved without merge policy."]
        )
    }

    func buildSnapshot(from selection: ResolvedSettingsSourceSelection) -> ResolvedSettingsSnapshot {
        let candidatesBySourceID = Dictionary(uniqueKeysWithValues: selection.candidates.map { ($0.source.id, $0) })
        let hasManagedCandidate = selection.candidates.contains(where: { $0.tier == .managed && $0.source.availability == .present })
        var mergedEntries: [ResolvedSettingsEntry] = []
        var aggregateIssues = selection.issues

        for entry in selection.entries {
            let participantPairs = entry.participants.compactMap { source -> (ResolutionSource, JSONValue)? in
                guard let candidate = candidatesBySourceID[source.id],
                      let value = candidate.value(for: entry.keyPath) else {
                    return nil
                }
                return (source, value)
            }

            let mergeResult = mergeEntry(
                keyPath: entry.keyPath,
                participants: participantPairs,
                inheritedIssues: entry.issues
            )
            aggregateIssues.append(contentsOf: mergeResult.issues)

            var entryNotes = mergeResult.notes

            let isManagedOnlyKey = registry.definition(for: entry.keyPath)?.isManagedOnly == true
            let winnerIsManaged = mergeResult.winningSource.map { source in
                source.scope == .managed
            } ?? false
            let hasOverriddenLowerScope = mergeResult.overriddenSources.contains(where: { $0.scope != .managed })

            if winnerIsManaged && hasOverriddenLowerScope {
                entryNotes.append("Managed policy is active for '\(entry.keyPath)'; lower-scope values are ineffective.")
            }

            if isManagedOnlyKey && !winnerIsManaged && !participantPairs.isEmpty {
                let nonManagedSources = participantPairs.filter { $0.0.scope != .managed }
                if !nonManagedSources.isEmpty {
                    let sourceNames = nonManagedSources.map { $0.0.identifier }.joined(separator: ", ")
                    aggregateIssues.append(
                        ResolutionIssue(
                            code: .conflict,
                            severity: .warning,
                            message: "Key '\(entry.keyPath)' is managed-only but appears in non-managed source(s): \(sourceNames).",
                            source: nonManagedSources.first?.0,
                            keyPath: entry.keyPath,
                            relatedSources: nonManagedSources.map(\.0)
                        )
                    )
                    entryNotes.append("Key '\(entry.keyPath)' is managed-only; non-managed contributions are reported as issues.")
                }
            }

            let value = ResolvedValue(
                effectiveValue: mergeResult.effectiveValue,
                winningSource: mergeResult.winningSource,
                trace: ResolutionTrace(
                    participants: entry.participants,
                    overridden: mergeResult.overriddenSources,
                    notes: entryNotes
                ),
                mergeMethod: mergeResult.mergeMethod,
                issues: mergeResult.issues,
                notes: entryNotes
            )
            mergedEntries.append(ResolvedSettingsEntry(keyPath: entry.keyPath, value: value))
        }

        var mergedNotes = selection.notes + ["Settings merge rules applied by key family."]
        if hasManagedCandidate {
            mergedNotes.append("Managed policy is active and takes precedence over all other scopes.")
        }
        return ResolvedSettingsSnapshot(entries: mergedEntries, issues: aggregateIssues, notes: mergedNotes)
    }

    private enum SettingsMergeRule {
        case replace
        case deepMergeObject
        case appendUnique
        case permissions
        case hooks
        case passthrough
    }

    private struct EntryMergeResult {
        let effectiveValue: JSONValue?
        let winningSource: ResolutionSource?
        let overriddenSources: [ResolutionSource]
        let mergeMethod: MergeMethod
        let issues: [ResolutionIssue]
        let notes: [String]
    }

    private func mergeEntry(
        keyPath: String,
        participants: [(ResolutionSource, JSONValue)],
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        let rule = mergeRule(for: keyPath)
        switch rule {
        case .replace:
            return mergeByReplace(participants: participants, keyPath: keyPath, inheritedIssues: inheritedIssues)
        case .deepMergeObject:
            return mergeDeepObject(participants: participants, keyPath: keyPath, inheritedIssues: inheritedIssues)
        case .appendUnique:
            return mergeAppendUnique(participants: participants, keyPath: keyPath, inheritedIssues: inheritedIssues)
        case .permissions:
            return mergePermissions(participants: participants, keyPath: keyPath, inheritedIssues: inheritedIssues)
        case .hooks:
            return mergeHooks(participants: participants, keyPath: keyPath, inheritedIssues: inheritedIssues)
        case .passthrough:
            return mergePassthrough(participants: participants, keyPath: keyPath, inheritedIssues: inheritedIssues)
        }
    }

    private func mergeRule(for keyPath: String) -> SettingsMergeRule {
        if keyPath == "permissions" {
            return .permissions
        }
        if keyPath == "hooks" {
            return .hooks
        }

        if let definition = registry.definition(for: keyPath) {
            return Self.mapMergeHint(definition.mergeHint)
        }

        return .passthrough
    }

    private static func mapMergeHint(_ hint: MergeMethod) -> SettingsMergeRule {
        switch hint {
        case .selectHighestPrecedence, .replace:
            return .replace
        case .deepMergeObject:
            return .deepMergeObject
        case .append, .appendUnique, .setUnion:
            return .appendUnique
        case .keyedByIdentifier:
            return .hooks
        case .passthrough:
            return .passthrough
        }
    }

    private func mergeByReplace(
        participants: [(ResolutionSource, JSONValue)],
        keyPath: String,
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        let winning = participants.first
        return EntryMergeResult(
            effectiveValue: winning?.1,
            winningSource: winning?.0,
            overriddenSources: participants.dropFirst().map(\.0),
            mergeMethod: .replace,
            issues: inheritedIssues,
            notes: ["Scalar override selected highest-precedence value for '\(keyPath)'."]
        )
    }

    private func mergePassthrough(
        participants: [(ResolutionSource, JSONValue)],
        keyPath: String,
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        let winning = participants.first
        return EntryMergeResult(
            effectiveValue: winning?.1,
            winningSource: winning?.0,
            overriddenSources: participants.dropFirst().map(\.0),
            mergeMethod: .passthrough,
            issues: inheritedIssues,
            notes: ["Used passthrough fallback for unsupported key '\(keyPath)'."]
        )
    }

    private func mergeDeepObject(
        participants: [(ResolutionSource, JSONValue)],
        keyPath: String,
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        var issues = inheritedIssues
        var objectParticipants: [(ResolutionSource, [String: JSONValue])] = []

        for (source, value) in participants {
            guard case let .object(objectValue) = value else {
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object for mergeable key '\(keyPath)'.",
                        source: source,
                        keyPath: keyPath
                    )
                )
                continue
            }
            objectParticipants.append((source, objectValue))
        }

        guard !objectParticipants.isEmpty else {
            issues.append(
                ResolutionIssue(
                    code: .unresolvedValue,
                    severity: .warning,
                    message: "No usable object contribution remained for key '\(keyPath)'.",
                    source: participants.first?.0,
                    keyPath: keyPath
                )
            )
            return EntryMergeResult(
                effectiveValue: nil,
                winningSource: nil,
                overriddenSources: [],
                mergeMethod: .deepMergeObject,
                issues: issues,
                notes: ["All participants were incompatible with object merge for '\(keyPath)'."]
            )
        }

        var merged: [String: JSONValue] = [:]
        for (_, objectValue) in objectParticipants.reversed() {
            for (childKey, childValue) in objectValue {
                merged[childKey] = childValue
            }
        }

        return EntryMergeResult(
            effectiveValue: .object(merged),
            winningSource: objectParticipants.first?.0,
            overriddenSources: objectParticipants.dropFirst().map(\.0),
            mergeMethod: .deepMergeObject,
            issues: issues,
            notes: ["Deep-merged object key '\(keyPath)' with high-precedence child override."]
        )
    }

    private func mergeAppendUnique(
        participants: [(ResolutionSource, JSONValue)],
        keyPath: String,
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        var issues = inheritedIssues
        var arrayParticipants: [(ResolutionSource, [JSONValue])] = []

        for (source, value) in participants {
            guard case let .array(items) = value else {
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected array for mergeable key '\(keyPath)'.",
                        source: source,
                        keyPath: keyPath
                    )
                )
                continue
            }
            arrayParticipants.append((source, items))
        }

        guard !arrayParticipants.isEmpty else {
            issues.append(
                ResolutionIssue(
                    code: .unresolvedValue,
                    severity: .warning,
                    message: "No usable array contribution remained for key '\(keyPath)'.",
                    source: participants.first?.0,
                    keyPath: keyPath
                )
            )
            return EntryMergeResult(
                effectiveValue: nil,
                winningSource: nil,
                overriddenSources: [],
                mergeMethod: .appendUnique,
                issues: issues,
                notes: ["All participants were incompatible with append-unique merge for '\(keyPath)'."]
            )
        }

        let mergedArray = Self.appendUniqueJSONArrays(arrayParticipants.map(\.1))
        return EntryMergeResult(
            effectiveValue: .array(mergedArray),
            winningSource: arrayParticipants.first?.0,
            overriddenSources: arrayParticipants.dropFirst().map(\.0),
            mergeMethod: .appendUnique,
            issues: issues,
            notes: ["Merged array key '\(keyPath)' by append + de-duplication."]
        )
    }

    private func mergePermissions(
        participants: [(ResolutionSource, JSONValue)],
        keyPath: String,
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        var issues = inheritedIssues
        var objectParticipants: [(ResolutionSource, [String: JSONValue])] = []

        for (source, value) in participants {
            guard case let .object(objectValue) = value else {
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object for '\(keyPath)' merge.",
                        source: source,
                        keyPath: keyPath
                    )
                )
                continue
            }
            objectParticipants.append((source, objectValue))
        }

        guard !objectParticipants.isEmpty else {
            issues.append(
                ResolutionIssue(
                    code: .unresolvedValue,
                    severity: .warning,
                    message: "No usable object contribution remained for key '\(keyPath)'.",
                    source: participants.first?.0,
                    keyPath: keyPath
                )
            )
            return EntryMergeResult(
                effectiveValue: nil,
                winningSource: nil,
                overriddenSources: [],
                mergeMethod: .deepMergeObject,
                issues: issues,
                notes: ["All participants were incompatible with permissions merge."]
            )
        }

        var merged: [String: JSONValue] = [:]
        for (_, objectValue) in objectParticipants.reversed() {
            for (childKey, childValue) in objectValue {
                merged[childKey] = childValue
            }
        }

        let allow = mergeUniqueStringList(
            from: objectParticipants,
            key: "allow",
            keyPath: "\(keyPath).allow",
            issues: &issues
        )
        let deny = mergeUniqueStringList(
            from: objectParticipants,
            key: "deny",
            keyPath: "\(keyPath).deny",
            issues: &issues
        )

        if !allow.isEmpty {
            merged["allow"] = .array(allow.map(JSONValue.string))
        }
        if !deny.isEmpty {
            merged["deny"] = .array(deny.map(JSONValue.string))
        }

        if let modeValue = selectHighestPrecedenceString(from: objectParticipants, key: "mode", keyPath: "\(keyPath).mode", issues: &issues) {
            merged["mode"] = .string(modeValue)
        }

        let conflicts = Set(allow).intersection(Set(deny))
        if !conflicts.isEmpty {
            issues.append(
                ResolutionIssue(
                    code: .conflict,
                    severity: .warning,
                    message: "permissions.allow and permissions.deny contain overlapping entries.",
                    source: objectParticipants.first?.0,
                    keyPath: keyPath,
                    relatedSources: objectParticipants.map(\.0)
                )
            )
        }

        return EntryMergeResult(
            effectiveValue: .object(merged),
            winningSource: objectParticipants.first?.0,
            overriddenSources: objectParticipants.dropFirst().map(\.0),
            mergeMethod: .deepMergeObject,
            issues: issues,
            notes: ["Merged permissions with append-unique allow/deny and scalar mode override."]
        )
    }

    private func mergeHooks(
        participants: [(ResolutionSource, JSONValue)],
        keyPath: String,
        inheritedIssues: [ResolutionIssue]
    ) -> EntryMergeResult {
        var issues = inheritedIssues
        var objectParticipants: [(ResolutionSource, [String: JSONValue])] = []

        for (source, value) in participants {
            guard case let .object(objectValue) = value else {
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected object for '\(keyPath)' merge.",
                        source: source,
                        keyPath: keyPath
                    )
                )
                continue
            }
            objectParticipants.append((source, objectValue))
        }

        guard !objectParticipants.isEmpty else {
            issues.append(
                ResolutionIssue(
                    code: .unresolvedValue,
                    severity: .warning,
                    message: "No usable object contribution remained for key '\(keyPath)'.",
                    source: participants.first?.0,
                    keyPath: keyPath
                )
            )
            return EntryMergeResult(
                effectiveValue: nil,
                winningSource: nil,
                overriddenSources: [],
                mergeMethod: .keyedByIdentifier,
                issues: issues,
                notes: ["All participants were incompatible with hooks merge."]
            )
        }

        enum HookEventContainer {
            case array(actions: [JSONValue])
            case object(matcher: JSONValue?, actions: [JSONValue], extras: [String: JSONValue])
        }

        func parseHookEvent(
            eventValue: JSONValue,
            source: ResolutionSource,
            eventPath: String,
            issues: inout [ResolutionIssue]
        ) -> HookEventContainer? {
            switch eventValue {
            case let .array(actions):
                return .array(actions: actions)
            case let .object(eventObject):
                guard let hooksValue = eventObject["hooks"] else {
                    issues.append(
                        ResolutionIssue(
                            code: .typeMismatch,
                            severity: .warning,
                            message: "Hook event object must include a 'hooks' array.",
                            source: source,
                            keyPath: eventPath
                        )
                    )
                    return nil
                }
                guard case let .array(actions) = hooksValue else {
                    issues.append(
                        ResolutionIssue(
                            code: .typeMismatch,
                            severity: .warning,
                            message: "Hook event 'hooks' field must be an array.",
                            source: source,
                            keyPath: "\(eventPath).hooks"
                        )
                    )
                    return nil
                }
                var extras = eventObject
                extras.removeValue(forKey: "hooks")
                extras.removeValue(forKey: "matcher")
                return .object(matcher: eventObject["matcher"], actions: actions, extras: extras)
            default:
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Hook event values must be an array or object with a 'hooks' array.",
                        source: source,
                        keyPath: eventPath
                    )
                )
                return nil
            }
        }

        var mergedEvents: [String: HookEventContainer] = [:]

        for (source, objectValue) in objectParticipants {
            for eventName in objectValue.keys.sorted() {
                let normalizedEventName = HookEventType(eventName: eventName).storageKey
                let eventPath = "\(keyPath).\(eventName)"
                guard let parsedEvent = parseHookEvent(
                    eventValue: objectValue[eventName] ?? .null,
                    source: source,
                    eventPath: eventPath,
                    issues: &issues
                ) else {
                    continue
                }

                guard let existing = mergedEvents[normalizedEventName] else {
                    mergedEvents[normalizedEventName] = parsedEvent
                    continue
                }

                switch (existing, parsedEvent) {
                case let (.array(existingActions), .array(newActions)):
                    let mergedActions = Self.appendUniqueJSONArrays([existingActions, newActions])
                    mergedEvents[normalizedEventName] = .array(actions: mergedActions)
                case let (.object(existingMatcher, existingActions, existingExtras), .object(newMatcher, newActions, newExtras)):
                    let mergedActions = Self.appendUniqueJSONArrays([existingActions, newActions])
                    var mergedExtras = existingExtras
                    for (extraKey, extraValue) in newExtras where mergedExtras[extraKey] == nil {
                        mergedExtras[extraKey] = extraValue
                    }
                    let mergedMatcher = existingMatcher ?? newMatcher
                    mergedEvents[normalizedEventName] = .object(matcher: mergedMatcher, actions: mergedActions, extras: mergedExtras)
                default:
                    issues.append(
                        ResolutionIssue(
                            code: .conflict,
                            severity: .warning,
                            message: "Conflicting hook event shapes were found; preserved highest-precedence shape.",
                            source: source,
                            keyPath: eventPath,
                            relatedSources: objectParticipants.map(\.0)
                        )
                    )
                }
            }
        }

        var mergedHooksObject: [String: JSONValue] = [:]
        for eventName in mergedEvents.keys.sorted() {
            guard let event = mergedEvents[eventName] else { continue }
            switch event {
            case let .array(actions):
                mergedHooksObject[eventName] = .array(actions)
            case let .object(matcher, actions, extras):
                var eventObject = extras
                eventObject["hooks"] = .array(actions)
                if let matcher {
                    eventObject["matcher"] = matcher
                }
                mergedHooksObject[eventName] = .object(eventObject)
            }
        }

        return EntryMergeResult(
            effectiveValue: .object(mergedHooksObject),
            winningSource: objectParticipants.first?.0,
            overriddenSources: objectParticipants.dropFirst().map(\.0),
            mergeMethod: .keyedByIdentifier,
            issues: issues,
            notes: ["Merged hooks by event identifier with action append + de-duplication."]
        )
    }

    private func mergeUniqueStringList(
        from participants: [(ResolutionSource, [String: JSONValue])],
        key: String,
        keyPath: String,
        issues: inout [ResolutionIssue]
    ) -> [String] {
        var valuesBySource: [[String]] = []

        for (source, objectValue) in participants {
            guard let rawValue = objectValue[key] else {
                continue
            }
            guard case let .array(items) = rawValue else {
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected array at '\(keyPath)'.",
                        source: source,
                        keyPath: keyPath
                    )
                )
                continue
            }

            var sourceValues: [String] = []
            for item in items {
                guard case let .string(stringValue) = item else {
                    issues.append(
                        ResolutionIssue(
                            code: .typeMismatch,
                            severity: .warning,
                            message: "Expected string entries at '\(keyPath)'.",
                            source: source,
                            keyPath: keyPath
                        )
                    )
                    continue
                }
                sourceValues.append(stringValue)
            }
            valuesBySource.append(sourceValues)
        }

        return Self.appendUniqueStrings(valuesBySource)
    }

    private func selectHighestPrecedenceString(
        from participants: [(ResolutionSource, [String: JSONValue])],
        key: String,
        keyPath: String,
        issues: inout [ResolutionIssue]
    ) -> String? {
        for (source, objectValue) in participants {
            guard let rawValue = objectValue[key] else {
                continue
            }
            guard case let .string(stringValue) = rawValue else {
                issues.append(
                    ResolutionIssue(
                        code: .typeMismatch,
                        severity: .warning,
                        message: "Expected string at '\(keyPath)'.",
                        source: source,
                        keyPath: keyPath
                    )
                )
                continue
            }
            return stringValue
        }
        return nil
    }

    private static func appendUniqueStrings(_ arrays: [[String]]) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        for values in arrays {
            for value in values where seen.insert(value).inserted {
                merged.append(value)
            }
        }
        return merged
    }

    private static func appendUniqueJSONArrays(_ arrays: [[JSONValue]]) -> [JSONValue] {
        var seen = Set<String>()
        var merged: [JSONValue] = []
        for array in arrays {
            for value in array {
                let identity = canonicalJSONFingerprint(value)
                if seen.insert(identity).inserted {
                    merged.append(value)
                }
            }
        }
        return merged
    }

    private static func canonicalJSONFingerprint(_ value: JSONValue) -> String {
        switch value {
        case let .string(v):
            return "s:\(v)"
        case let .number(v):
            return "n:\(v)"
        case let .bool(v):
            return "b:\(v)"
        case .null:
            return "null"
        case let .array(values):
            return "a:[\(values.map(canonicalJSONFingerprint).joined(separator: ","))]"
        case let .object(objectValues):
            let sortedPairs = objectValues.keys.sorted().map { key in
                "\(key):\(canonicalJSONFingerprint(objectValues[key] ?? .null))"
            }
            return "o:{\(sortedPairs.joined(separator: ","))}"
        }
    }

    private static func sortCandidates(_ candidates: [SettingsSourceCandidate]) -> [SettingsSourceCandidate] {
        candidates.sorted {
            if $0.tier != $1.tier {
                return $0.tier < $1.tier
            }
            if $0.precedenceRank != $1.precedenceRank {
                return $0.precedenceRank < $1.precedenceRank
            }
            return $0.source.id < $1.source.id
        }
    }

    private static func collectCandidateIssues(_ candidates: [SettingsSourceCandidate]) -> [ResolutionIssue] {
        var issues: [ResolutionIssue] = []

        for candidate in candidates {
            issues.append(contentsOf: candidate.issues)

            switch candidate.source.availability {
            case .present:
                continue
            case .missing:
                issues.append(
                    ResolutionIssue(
                        code: .missingSource,
                        severity: .warning,
                        message: "Settings source is missing and was skipped.",
                        source: candidate.source
                    )
                )
            case .invalid:
                issues.append(
                    ResolutionIssue(
                        code: .invalidSource,
                        severity: .error,
                        message: "Settings source is invalid and could not contribute values.",
                        source: candidate.source
                    )
                )
            case .inaccessible:
                issues.append(
                    ResolutionIssue(
                        code: .inaccessibleSource,
                        severity: .error,
                        message: "Settings source is inaccessible and could not be read.",
                        source: candidate.source
                    )
                )
            }
        }

        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct ResolvedSettingsEntry: Equatable, Sendable {
    let keyPath: String
    let value: ResolvedValue<JSONValue>
}

struct ResolvedSettingsSnapshot: Equatable, Sendable {
    let entries: [ResolvedSettingsEntry]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(entries: [ResolvedSettingsEntry], issues: [ResolutionIssue] = [], notes: [String] = []) {
        self.entries = entries.sorted { $0.keyPath < $1.keyPath }
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

struct ResolvedInstructionBlock: Equatable, Sendable {
    let blockID: String
    let content: ResolvedValue<String>
}

struct ResolvedInstructionMemoryTopic: Equatable, Sendable {
    let topicID: String
    let title: String
    let source: ResolutionSource
    let availability: ResolutionAvailability
}

struct ResolvedInstructionImportEdge: Equatable, Sendable {
    let parentBlockID: String
    let childBlockID: String?
    let rawToken: String
    let tokenRange: SourceRange?
    let resolvedPath: String?
    let depth: Int
    let isCycle: Bool
}

struct ResolvedInstructionSnapshot: Equatable, Sendable {
    let composedInstructions: ResolvedValue<String>
    let orderedBlocks: [ResolvedInstructionBlock]
    let startupMemoryTopics: [ResolvedInstructionMemoryTopic]
    let onDemandMemoryTopics: [ResolvedInstructionMemoryTopic]
    let importEdges: [ResolvedInstructionImportEdge]
    let rootLoadOrder: [ResolutionSource]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(
        composedInstructions: ResolvedValue<String>,
        orderedBlocks: [ResolvedInstructionBlock] = [],
        startupMemoryTopics: [ResolvedInstructionMemoryTopic] = [],
        onDemandMemoryTopics: [ResolvedInstructionMemoryTopic] = [],
        importEdges: [ResolvedInstructionImportEdge] = [],
        rootLoadOrder: [ResolutionSource] = [],
        issues: [ResolutionIssue] = [],
        notes: [String] = []
    ) {
        self.composedInstructions = composedInstructions
        self.orderedBlocks = orderedBlocks
        self.startupMemoryTopics = startupMemoryTopics.sorted { $0.topicID < $1.topicID }
        self.onDemandMemoryTopics = onDemandMemoryTopics.sorted { $0.topicID < $1.topicID }
        self.importEdges = importEdges
        self.rootLoadOrder = rootLoadOrder
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

enum McpSourceTier: Int, Comparable, CaseIterable, Sendable {
    case local = 0
    case project = 1
    case user = 2
    case managed = 3

    static func < (lhs: McpSourceTier, rhs: McpSourceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum McpCandidateUsability: String, Equatable, Sendable {
    case usable
    case unusable
}

struct McpDocumentServerEntry: Equatable, Sendable {
    let serverID: String
    let rawConfig: JSONValue?
    let parseOrder: Int
    let issues: [ResolutionIssue]

    init(
        serverID: String,
        rawConfig: JSONValue?,
        parseOrder: Int,
        issues: [ResolutionIssue] = []
    ) {
        self.serverID = serverID
        self.rawConfig = rawConfig
        self.parseOrder = parseOrder
        self.issues = issues.sorted { $0.id < $1.id }
    }
}

struct McpDocumentCandidate: Equatable, Sendable {
    let tier: McpSourceTier
    let source: ResolutionSource
    let servers: [McpDocumentServerEntry]
    let issues: [ResolutionIssue]

    init(
        tier: McpSourceTier,
        source: ResolutionSource,
        servers: [McpDocumentServerEntry],
        issues: [ResolutionIssue] = []
    ) {
        self.tier = tier
        self.source = source
        self.servers = servers
        self.issues = issues.sorted { $0.id < $1.id }
    }
}

struct McpSourceCandidate: Equatable, Sendable {
    let tier: McpSourceTier
    let source: ResolutionSource
    let serverID: String
    let rawConfig: JSONValue?
    let parseOrder: Int
    let issues: [ResolutionIssue]

    var usability: McpCandidateUsability {
        guard source.availability == .present else {
            return .unusable
        }
        guard let rawConfig else {
            return .unusable
        }
        guard case .object = rawConfig else {
            return .unusable
        }
        let hasErrorIssue = issues.contains(where: { $0.severity == .error })
        return hasErrorIssue ? .unusable : .usable
    }
}

enum McpEnvironmentClassification: String, Equatable, Sendable {
    case staticLiteral
    case containsReference
    case unresolvedReference
}

struct McpEnvironmentNote: Equatable, Sendable {
    let fieldPath: String
    let classification: McpEnvironmentClassification
    let message: String
}

struct MCPResolver {
    func buildCandidates(from documents: [McpDocumentCandidate]) -> [McpSourceCandidate] {
        let orderedDocuments = documents.sorted {
            if $0.tier != $1.tier {
                return $0.tier < $1.tier
            }
            return $0.source.id < $1.source.id
        }

        var candidates: [McpSourceCandidate] = []
        for document in orderedDocuments {
            let orderedServers = document.servers.sorted {
                if $0.parseOrder != $1.parseOrder {
                    return $0.parseOrder < $1.parseOrder
                }
                return $0.serverID < $1.serverID
            }

            for server in orderedServers {
                candidates.append(
                    McpSourceCandidate(
                        tier: document.tier,
                        source: document.source,
                        serverID: server.serverID,
                        rawConfig: server.rawConfig,
                        parseOrder: server.parseOrder,
                        issues: (document.issues + server.issues).sorted { $0.id < $1.id }
                    )
                )
            }
        }

        return candidates
    }

    func resolve(documents: [McpDocumentCandidate]) -> ResolvedMcpSnapshot {
        resolve(candidates: buildCandidates(from: documents))
    }

    func resolve(candidates: [McpSourceCandidate]) -> ResolvedMcpSnapshot {
        let orderedCandidates = sortCandidates(candidates)
        let allServerIDs = Set(orderedCandidates.map(\.serverID)).sorted()

        var snapshotEntries: [ResolvedMcpServerEntry] = []
        var snapshotIssues: [ResolutionIssue] = collectGlobalCandidateIssues(orderedCandidates)
        var snapshotNotes: [String] = [
            "MCP servers resolved with deterministic local -> project -> user -> managed precedence."
        ]

        for serverID in allServerIDs {
            let serverCandidates = orderedCandidates.filter { $0.serverID == serverID }
            let selectedBySource = selectPerSourceCandidates(serverID: serverID, candidates: serverCandidates)
            let serverEntry = resolveServer(serverID: serverID, candidates: selectedBySource)
            snapshotEntries.append(serverEntry)
            snapshotIssues.append(contentsOf: serverEntry.resolvedConfig.issues)
        }

        if allServerIDs.isEmpty {
            snapshotNotes.append("No MCP server identifiers were present in available sources.")
        }

        return ResolvedMcpSnapshot(
            servers: snapshotEntries,
            issues: deduplicatedIssues(snapshotIssues),
            notes: snapshotNotes
        )
    }

    private func resolveServer(serverID: String, candidates: [McpSourceCandidate]) -> ResolvedMcpServerEntry {
        var issues: [ResolutionIssue] = []
        var notes: [String] = []
        var usable: [McpSourceCandidate] = []
        var fallbackSources: [ResolutionSource] = []

        for candidate in candidates {
            issues.append(contentsOf: candidate.issues)
            issues.append(contentsOf: availabilityIssues(for: candidate.source))

            switch candidate.usability {
            case .usable:
                usable.append(candidate)
            case .unusable:
                if candidate.source.availability == .present, let rawConfig = candidate.rawConfig {
                    if case .object = rawConfig {
                        // Invalid by issue severity only; no extra shape issue needed.
                    } else {
                        issues.append(
                            ResolutionIssue(
                                code: .typeMismatch,
                                severity: .warning,
                                message: "MCP server '\(serverID)' must be an object to be considered usable.",
                                source: candidate.source,
                                keyPath: serverID
                            )
                        )
                    }
                } else if candidate.source.availability == .present {
                    issues.append(
                        ResolutionIssue(
                            code: .invalidSource,
                            severity: .warning,
                            message: "MCP server '\(serverID)' has no usable configuration payload.",
                            source: candidate.source,
                            keyPath: serverID
                        )
                    )
                }
                fallbackSources.append(candidate.source)
            }
        }

        let winner = usable.first
        let participants = candidates.map(\.source)
        let overridden = winner == nil
            ? participants
            : candidates.compactMap { candidate in
                candidate.source.id == winner?.source.id ? nil : candidate.source
            }

        if usable.count > 1 {
            notes.append("Duplicate MCP server id '\(serverID)' resolved by precedence.")
        }

        if winner != nil, !fallbackSources.isEmpty {
            issues.append(
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .warning,
                    message: "Higher-precedence MCP definitions for '\(serverID)' were unusable; fell back to next usable source.",
                    source: winner?.source,
                    keyPath: serverID,
                    relatedSources: fallbackSources
                )
            )
            notes.append("Fallback was required before selecting effective MCP definition.")
        }

        if winner == nil {
            issues.append(
                ResolutionIssue(
                    code: .unresolvedValue,
                    severity: .warning,
                    message: "No usable MCP definition remained for '\(serverID)'.",
                    source: candidates.first?.source,
                    keyPath: serverID,
                    relatedSources: candidates.map(\.source)
                )
            )
        }

        let environmentNotes: [McpEnvironmentNote]
        if let winnerValue = winner?.rawConfig {
            environmentNotes = environmentNotesForConfig(winnerValue)
            notes.append(contentsOf: environmentNotes.map(\.message))
        } else {
            environmentNotes = []
        }

        return ResolvedMcpServerEntry(
            serverID: serverID,
            resolvedConfig: ResolvedValue(
                effectiveValue: winner?.rawConfig,
                winningSource: winner?.source,
                trace: ResolutionTrace(
                    participants: participants,
                    overridden: overridden,
                    notes: notes
                ),
                mergeMethod: .selectHighestPrecedence,
                issues: deduplicatedIssues(issues),
                notes: notes
            ),
            environmentNotes: environmentNotes
        )
    }

    private func sortCandidates(_ candidates: [McpSourceCandidate]) -> [McpSourceCandidate] {
        candidates.sorted {
            if $0.serverID != $1.serverID {
                return $0.serverID < $1.serverID
            }
            if $0.tier != $1.tier {
                return $0.tier < $1.tier
            }
            if $0.source.id != $1.source.id {
                return $0.source.id < $1.source.id
            }
            return $0.parseOrder < $1.parseOrder
        }
    }

    private func selectPerSourceCandidates(
        serverID: String,
        candidates: [McpSourceCandidate]
    ) -> [McpSourceCandidate] {
        let grouped = Dictionary(grouping: candidates) { candidate in
            "\(candidate.tier.rawValue)::\(candidate.source.id)"
        }

        var selected: [McpSourceCandidate] = []
        for groupKey in grouped.keys.sorted() {
            guard let sourceCandidates = grouped[groupKey] else { continue }
            let ordered = sourceCandidates.sorted { lhs, rhs in
                if lhs.parseOrder != rhs.parseOrder {
                    return lhs.parseOrder < rhs.parseOrder
                }
                return lhs.source.id < rhs.source.id
            }

            guard let selectedCandidate = ordered.last else { continue }
            if ordered.count == 1 {
                selected.append(selectedCandidate)
                continue
            }

            let duplicateIssue = ResolutionIssue(
                code: .duplicateIdentifier,
                severity: .warning,
                message: "Duplicate MCP server id '\(serverID)' found within the same source. Used last-defined entry by parse order.",
                source: selectedCandidate.source,
                keyPath: serverID,
                relatedSources: ordered.map(\.source)
            )

            let mergedIssues = deduplicatedIssues(selectedCandidate.issues + [duplicateIssue])
            selected.append(
                McpSourceCandidate(
                    tier: selectedCandidate.tier,
                    source: selectedCandidate.source,
                    serverID: selectedCandidate.serverID,
                    rawConfig: selectedCandidate.rawConfig,
                    parseOrder: selectedCandidate.parseOrder,
                    issues: mergedIssues
                )
            )
        }

        return selected.sorted {
            if $0.tier != $1.tier {
                return $0.tier < $1.tier
            }
            if $0.source.id != $1.source.id {
                return $0.source.id < $1.source.id
            }
            return $0.parseOrder < $1.parseOrder
        }
    }

    private func collectGlobalCandidateIssues(_ candidates: [McpSourceCandidate]) -> [ResolutionIssue] {
        deduplicatedIssues(candidates.flatMap(\.issues))
    }

    private func availabilityIssues(for source: ResolutionSource) -> [ResolutionIssue] {
        switch source.availability {
        case .present:
            return []
        case .missing:
            return [
                ResolutionIssue(
                    code: .missingSource,
                    severity: .warning,
                    message: "MCP source is missing and was skipped.",
                    source: source
                )
            ]
        case .invalid:
            return [
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .error,
                    message: "MCP source is invalid and could not contribute values.",
                    source: source
                )
            ]
        case .inaccessible:
            return [
                ResolutionIssue(
                    code: .inaccessibleSource,
                    severity: .error,
                    message: "MCP source is inaccessible and could not be read.",
                    source: source
                )
            ]
        }
    }

    private func environmentNotesForConfig(_ value: JSONValue) -> [McpEnvironmentNote] {
        guard case let .object(object) = value else {
            return []
        }

        var notes: [McpEnvironmentNote] = []
        if let command = stringValue(object["command"]) {
            notes.append(environmentNote(fieldPath: "command", value: command))
        }
        if let url = stringValue(object["url"]) {
            notes.append(environmentNote(fieldPath: "url", value: url))
        }

        if let args = arrayValue(object["args"]) {
            for (index, item) in args.enumerated() {
                guard let stringItem = stringValue(item) else { continue }
                notes.append(environmentNote(fieldPath: "args[\(index)]", value: stringItem))
            }
        }

        if let env = objectValue(object["env"]) {
            for key in env.keys.sorted() {
                guard let stringValue = stringValue(env[key]) else { continue }
                notes.append(environmentNote(fieldPath: "env.\(key)", value: stringValue))
            }
        }

        if let headers = objectValue(object["headers"]) {
            for key in headers.keys.sorted() {
                guard let stringValue = stringValue(headers[key]) else { continue }
                notes.append(environmentNote(fieldPath: "headers.\(key)", value: stringValue))
            }
        }

        return notes.sorted { lhs, rhs in
            if lhs.fieldPath != rhs.fieldPath {
                return lhs.fieldPath < rhs.fieldPath
            }
            return lhs.message < rhs.message
        }
    }

    private func environmentNote(fieldPath: String, value: String) -> McpEnvironmentNote {
        let classification = classifyEnvironmentReference(value)
        let message: String
        switch classification {
        case .staticLiteral:
            message = "MCP field '\(fieldPath)' is a static literal."
        case .containsReference:
            message = "MCP field '\(fieldPath)' contains an environment reference pattern."
        case .unresolvedReference:
            message = "MCP field '\(fieldPath)' contains an unresolved environment reference pattern."
        }
        return McpEnvironmentNote(fieldPath: fieldPath, classification: classification, message: message)
    }

    private func classifyEnvironmentReference(_ value: String) -> McpEnvironmentClassification {
        if value.contains("$") == false {
            return .staticLiteral
        }
        if Self.matchesValidEnvReference(value) {
            return .containsReference
        }
        return .unresolvedReference
    }

    private static func matchesValidEnvReference(_ value: String) -> Bool {
        let patterns = [
            #"\$\{[A-Za-z_][A-Za-z0-9_]*\}"#,
            #"\$[A-Za-z_][A-Za-z0-9_]*"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            if regex.firstMatch(in: value, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        guard case let .string(string) = value else { return nil }
        return string
    }

    private func arrayValue(_ value: JSONValue?) -> [JSONValue]? {
        guard let value else { return nil }
        guard case let .array(array) = value else { return nil }
        return array
    }

    private func objectValue(_ value: JSONValue?) -> [String: JSONValue]? {
        guard let value else { return nil }
        guard case let .object(object) = value else { return nil }
        return object
    }

    private func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct ResolvedMcpServerEntry: Equatable, Sendable {
    let serverID: String
    let resolvedConfig: ResolvedValue<JSONValue>
    let environmentNotes: [McpEnvironmentNote]

    init(
        serverID: String,
        resolvedConfig: ResolvedValue<JSONValue>,
        environmentNotes: [McpEnvironmentNote] = []
    ) {
        self.serverID = serverID
        self.resolvedConfig = resolvedConfig
        self.environmentNotes = environmentNotes.sorted { lhs, rhs in
            if lhs.fieldPath != rhs.fieldPath {
                return lhs.fieldPath < rhs.fieldPath
            }
            return lhs.message < rhs.message
        }
    }
}

struct ResolvedMcpSnapshot: Equatable, Sendable {
    let servers: [ResolvedMcpServerEntry]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(servers: [ResolvedMcpServerEntry], issues: [ResolutionIssue] = [], notes: [String] = []) {
        self.servers = servers.sorted { $0.serverID < $1.serverID }
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

struct ResolvedAgentEntry: Equatable, Sendable {
    let agentID: String
    let source: ResolutionSource
    let definition: ResolvedValue<ParsedAgentDocument>
    let visibility: ResolvedValue<VisibilityState>
    let isVisible: ResolvedValue<Bool>
}

struct ResolvedAgentSnapshot: Equatable, Sendable {
    let agents: [ResolvedAgentEntry]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(agents: [ResolvedAgentEntry], issues: [ResolutionIssue] = [], notes: [String] = []) {
        self.agents = agents.sorted { lhs, rhs in
            let lhsStateRank = (lhs.visibility.effectiveValue ?? .invalid).sortRank
            let rhsStateRank = (rhs.visibility.effectiveValue ?? .invalid).sortRank
            if lhsStateRank != rhsStateRank {
                return lhsStateRank < rhsStateRank
            }
            if lhs.agentID != rhs.agentID {
                return lhs.agentID < rhs.agentID
            }
            return lhs.source.id < rhs.source.id
        }
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

struct ResolvedSkillEntry: Equatable, Sendable {
    let skillID: String
    let source: ResolutionSource
    let definition: ResolvedValue<ParsedSkillDocument>
    let visibility: ResolvedValue<VisibilityState>
    let isVisible: ResolvedValue<Bool>
}

struct ResolvedSkillSnapshot: Equatable, Sendable {
    let skills: [ResolvedSkillEntry]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(skills: [ResolvedSkillEntry], issues: [ResolutionIssue] = [], notes: [String] = []) {
        self.skills = skills.sorted { lhs, rhs in
            let lhsStateRank = (lhs.visibility.effectiveValue ?? .invalid).sortRank
            let rhsStateRank = (rhs.visibility.effectiveValue ?? .invalid).sortRank
            if lhsStateRank != rhsStateRank {
                return lhsStateRank < rhsStateRank
            }
            if lhs.skillID != rhs.skillID {
                return lhs.skillID < rhs.skillID
            }
            return lhs.source.id < rhs.source.id
        }
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

enum VisibilityState: String, Equatable, Sendable {
    case effective
    case overridden
    case invalid
    case unavailable

    var sortRank: Int {
        switch self {
        case .effective:
            return 0
        case .overridden:
            return 1
        case .invalid:
            return 2
        case .unavailable:
            return 3
        }
    }

    var isVisible: Bool {
        self == .effective
    }
}

enum AgentSourceTier: Int, Comparable, CaseIterable, Sendable {
    case project = 0
    case user = 1

    static func < (lhs: AgentSourceTier, rhs: AgentSourceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct AgentDocumentCandidate: Equatable, Sendable {
    let tier: AgentSourceTier
    let source: ResolutionSource
    let document: ParsedAgentDocument?
    let issues: [ResolutionIssue]

    init(
        tier: AgentSourceTier,
        source: ResolutionSource,
        document: ParsedAgentDocument?,
        issues: [ResolutionIssue] = []
    ) {
        self.tier = tier
        self.source = source
        self.document = document
        self.issues = issues.sorted { $0.id < $1.id }
    }
}

enum SkillSourceTier: Int, Comparable, CaseIterable, Sendable {
    case project = 0
    case user = 1

    static func < (lhs: SkillSourceTier, rhs: SkillSourceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SkillDocumentCandidate: Equatable, Sendable {
    let tier: SkillSourceTier
    let source: ResolutionSource
    let document: ParsedSkillDocument?
    let issues: [ResolutionIssue]

    init(
        tier: SkillSourceTier,
        source: ResolutionSource,
        document: ParsedSkillDocument?,
        issues: [ResolutionIssue] = []
    ) {
        self.tier = tier
        self.source = source
        self.document = document
        self.issues = issues.sorted { $0.id < $1.id }
    }
}

struct AgentResolver {
    private struct EvaluatedCandidate {
        let candidate: AgentDocumentCandidate
        let identityKey: String?
        let issues: [ResolutionIssue]
        let state: VisibilityState
    }

    func resolve(candidates: [AgentDocumentCandidate]) -> ResolvedAgentSnapshot {
        let orderedCandidates = sortCandidates(candidates)
        var evaluated: [EvaluatedCandidate] = []
        var snapshotIssues: [ResolutionIssue] = []

        for candidate in orderedCandidates {
            let evaluation = evaluate(candidate)
            evaluated.append(evaluation)
            snapshotIssues.append(contentsOf: evaluation.issues)
        }

        let usableByIdentity = Dictionary(grouping: evaluated.filter { evaluatedCandidate in
            evaluatedCandidate.state != .invalid && evaluatedCandidate.state != .unavailable
        }) { evaluatedCandidate in
            evaluatedCandidate.identityKey ?? ""
        }

        var winnerByIdentity: [String: EvaluatedCandidate] = [:]
        var extraIssuesBySourceID: [String: [ResolutionIssue]] = [:]
        var stateOverridesBySourceID: [String: VisibilityState] = [:]

        for identity in usableByIdentity.keys.sorted() {
            guard let grouped = usableByIdentity[identity], !grouped.isEmpty else {
                continue
            }
            let orderedGroup = grouped.sorted { lhs, rhs in
                if lhs.candidate.tier != rhs.candidate.tier {
                    return lhs.candidate.tier < rhs.candidate.tier
                }
                return lhs.candidate.source.id < rhs.candidate.source.id
            }

            guard let winner = orderedGroup.first else { continue }
            winnerByIdentity[identity] = winner
            stateOverridesBySourceID[winner.candidate.source.id] = .effective

            let sameScope = Dictionary(grouping: orderedGroup) { $0.candidate.tier }
            for tier in sameScope.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let tierMembers = sameScope[tier], tierMembers.count > 1 else { continue }
                let relatedSources = tierMembers.map { $0.candidate.source }
                for member in tierMembers {
                    let issue = ResolutionIssue(
                        code: .duplicateIdentifier,
                        severity: .warning,
                        message: "Duplicate agent identity '\(identity)' found in the same scope; deterministic tiebreak by source id was applied.",
                        source: member.candidate.source,
                        keyPath: identity,
                        relatedSources: relatedSources
                    )
                    extraIssuesBySourceID[member.candidate.source.id, default: []].append(issue)
                    snapshotIssues.append(issue)
                }
            }

            if orderedGroup.count > 1 {
                let relatedSources = orderedGroup.map { $0.candidate.source }
                for member in orderedGroup.dropFirst() {
                    stateOverridesBySourceID[member.candidate.source.id] = .overridden
                    let issue = ResolutionIssue(
                        code: .duplicateIdentifier,
                        severity: .warning,
                        message: "Agent identity '\(identity)' was overridden by a higher-precedence definition.",
                        source: member.candidate.source,
                        keyPath: identity,
                        relatedSources: relatedSources
                    )
                    extraIssuesBySourceID[member.candidate.source.id, default: []].append(issue)
                    snapshotIssues.append(issue)
                }
            }
        }

        let entries = evaluated.map { evaluation -> ResolvedAgentEntry in
            let source = evaluation.candidate.source
            let identity = evaluation.identityKey ?? unresolvedIdentity(fallback: source.identifier)
            let effectiveState = stateOverridesBySourceID[source.id] ?? evaluation.state
            let winner = evaluation.identityKey.flatMap { winnerByIdentity[$0] }?.candidate.source
            let participants = evaluation.identityKey.flatMap { identityKey in
                usableByIdentity[identityKey]?.map { $0.candidate.source }
            } ?? [source]
            let overriddenSources = winner == nil
                ? []
                : participants.filter { $0.id != winner?.id }

            let entryIssues = deduplicatedIssues(
                evaluation.issues + (extraIssuesBySourceID[source.id] ?? [])
            )
            let stateNote = "Agent entry resolved as \(effectiveState.rawValue)."

            let definition = ResolvedValue(
                effectiveValue: evaluation.candidate.document,
                winningSource: evaluation.candidate.document == nil ? nil : source,
                trace: ResolutionTrace(
                    participants: participants,
                    overridden: overriddenSources,
                    notes: [stateNote]
                ),
                mergeMethod: .selectHighestPrecedence,
                issues: entryIssues,
                notes: [stateNote]
            )
            let visibility = ResolvedValue(
                effectiveValue: effectiveState,
                winningSource: winner,
                trace: ResolutionTrace(
                    participants: participants,
                    overridden: overriddenSources,
                    notes: ["Agent visibility computed with project-over-user precedence."]
                ),
                mergeMethod: .selectHighestPrecedence,
                issues: entryIssues,
                notes: ["Agent visibility computed with project-over-user precedence."]
            )
            let isVisible = ResolvedValue(
                effectiveValue: effectiveState.isVisible,
                winningSource: winner,
                trace: visibility.trace,
                mergeMethod: .selectHighestPrecedence,
                issues: entryIssues,
                notes: visibility.notes
            )

            return ResolvedAgentEntry(
                agentID: identity,
                source: source,
                definition: definition,
                visibility: visibility,
                isVisible: isVisible
            )
        }

        return ResolvedAgentSnapshot(
            agents: entries,
            issues: deduplicatedIssues(snapshotIssues),
            notes: [
                "Agent identities are normalized as lowercase, whitespace-collapsed keys.",
                "Agent precedence is project over user with deterministic source-id tiebreaks."
            ]
        )
    }

    private func evaluate(_ candidate: AgentDocumentCandidate) -> EvaluatedCandidate {
        var issues = candidate.issues
        issues.append(contentsOf: availabilityIssues(for: candidate.source, subject: "Agent"))

        let identity = agentIdentity(for: candidate)
        if candidate.source.availability == .present, identity == nil {
            issues.append(
                ResolutionIssue(
                    code: .unsupportedShape,
                    severity: .error,
                    message: "Agent definition is missing a usable identity key (frontmatter name or file stem).",
                    source: candidate.source
                )
            )
        }
        if candidate.source.availability == .present, candidate.document == nil {
            issues.append(
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .error,
                    message: "Agent source is present but did not produce a parsed document.",
                    source: candidate.source
                )
            )
        }

        let hasError = issues.contains(where: { $0.severity == .error })
        let state: VisibilityState
        if candidate.source.availability != .present {
            state = .unavailable
        } else if hasError {
            state = .invalid
        } else {
            state = .effective
        }

        return EvaluatedCandidate(
            candidate: candidate,
            identityKey: identity,
            issues: deduplicatedIssues(issues),
            state: state
        )
    }

    private func agentIdentity(for candidate: AgentDocumentCandidate) -> String? {
        let frontmatterName = candidate.document?.frontmatter?.name
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        if let frontmatterName {
            return normalizeIdentity(frontmatterName)
        }

        if let sourcePath = candidate.source.sourcePath {
            let fileStem = URL(fileURLWithPath: sourcePath).deletingPathExtension().lastPathComponent
            if let normalizedFileStem = normalizeIdentity(fileStem), !normalizedFileStem.isEmpty {
                return normalizedFileStem
            }
        }

        return normalizeIdentity(candidate.source.identifier)
    }

    private func normalizeIdentity(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        let collapsed = components.joined(separator: "-").lowercased()
        return collapsed.isEmpty ? nil : collapsed
    }

    private func sortCandidates(_ candidates: [AgentDocumentCandidate]) -> [AgentDocumentCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.tier != rhs.tier {
                return lhs.tier < rhs.tier
            }
            return lhs.source.id < rhs.source.id
        }
    }

    private func availabilityIssues(for source: ResolutionSource, subject: String) -> [ResolutionIssue] {
        switch source.availability {
        case .present:
            return []
        case .missing:
            return [
                ResolutionIssue(
                    code: .missingSource,
                    severity: .warning,
                    message: "\(subject) source is missing and was skipped.",
                    source: source
                )
            ]
        case .invalid:
            return [
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .error,
                    message: "\(subject) source is invalid and could not contribute definitions.",
                    source: source
                )
            ]
        case .inaccessible:
            return [
                ResolutionIssue(
                    code: .inaccessibleSource,
                    severity: .error,
                    message: "\(subject) source is inaccessible and could not be read.",
                    source: source
                )
            ]
        }
    }

    private func unresolvedIdentity(fallback: String) -> String {
        "unresolved-\(fallback.lowercased())"
    }

    private func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct SkillResolver {
    private struct EvaluatedCandidate {
        let candidate: SkillDocumentCandidate
        let identityKey: String?
        let issues: [ResolutionIssue]
        let state: VisibilityState
    }

    func resolve(candidates: [SkillDocumentCandidate]) -> ResolvedSkillSnapshot {
        let orderedCandidates = sortCandidates(candidates)
        var evaluated: [EvaluatedCandidate] = []
        var snapshotIssues: [ResolutionIssue] = []

        for candidate in orderedCandidates {
            let evaluation = evaluate(candidate)
            evaluated.append(evaluation)
            snapshotIssues.append(contentsOf: evaluation.issues)
        }

        let usableByIdentity = Dictionary(grouping: evaluated.filter { evaluatedCandidate in
            evaluatedCandidate.state != .invalid && evaluatedCandidate.state != .unavailable
        }) { evaluatedCandidate in
            evaluatedCandidate.identityKey ?? ""
        }

        var winnerByIdentity: [String: EvaluatedCandidate] = [:]
        var extraIssuesBySourceID: [String: [ResolutionIssue]] = [:]
        var stateOverridesBySourceID: [String: VisibilityState] = [:]

        for identity in usableByIdentity.keys.sorted() {
            guard let grouped = usableByIdentity[identity], !grouped.isEmpty else {
                continue
            }
            let orderedGroup = grouped.sorted { lhs, rhs in
                if lhs.candidate.tier != rhs.candidate.tier {
                    return lhs.candidate.tier < rhs.candidate.tier
                }
                return lhs.candidate.source.id < rhs.candidate.source.id
            }

            guard let winner = orderedGroup.first else { continue }
            winnerByIdentity[identity] = winner
            stateOverridesBySourceID[winner.candidate.source.id] = .effective

            let sameScope = Dictionary(grouping: orderedGroup) { $0.candidate.tier }
            for tier in sameScope.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let tierMembers = sameScope[tier], tierMembers.count > 1 else { continue }
                let relatedSources = tierMembers.map { $0.candidate.source }
                for member in tierMembers {
                    let issue = ResolutionIssue(
                        code: .duplicateIdentifier,
                        severity: .warning,
                        message: "Duplicate skill identity '\(identity)' found in the same scope; deterministic tiebreak by source id was applied.",
                        source: member.candidate.source,
                        keyPath: identity,
                        relatedSources: relatedSources
                    )
                    extraIssuesBySourceID[member.candidate.source.id, default: []].append(issue)
                    snapshotIssues.append(issue)
                }
            }

            if orderedGroup.count > 1 {
                let relatedSources = orderedGroup.map { $0.candidate.source }
                for member in orderedGroup.dropFirst() {
                    stateOverridesBySourceID[member.candidate.source.id] = .overridden
                    let issue = ResolutionIssue(
                        code: .duplicateIdentifier,
                        severity: .warning,
                        message: "Skill identity '\(identity)' was overridden by a higher-precedence definition.",
                        source: member.candidate.source,
                        keyPath: identity,
                        relatedSources: relatedSources
                    )
                    extraIssuesBySourceID[member.candidate.source.id, default: []].append(issue)
                    snapshotIssues.append(issue)
                }
            }
        }

        let entries = evaluated.map { evaluation -> ResolvedSkillEntry in
            let source = evaluation.candidate.source
            let identity = evaluation.identityKey ?? unresolvedIdentity(fallback: source.identifier)
            let effectiveState = stateOverridesBySourceID[source.id] ?? evaluation.state
            let winner = evaluation.identityKey.flatMap { winnerByIdentity[$0] }?.candidate.source
            let participants = evaluation.identityKey.flatMap { identityKey in
                usableByIdentity[identityKey]?.map { $0.candidate.source }
            } ?? [source]
            let overriddenSources = winner == nil
                ? []
                : participants.filter { $0.id != winner?.id }

            let entryIssues = deduplicatedIssues(
                evaluation.issues + (extraIssuesBySourceID[source.id] ?? [])
            )
            let stateNote = "Skill entry resolved as \(effectiveState.rawValue)."

            let definition = ResolvedValue(
                effectiveValue: evaluation.candidate.document,
                winningSource: evaluation.candidate.document == nil ? nil : source,
                trace: ResolutionTrace(
                    participants: participants,
                    overridden: overriddenSources,
                    notes: [stateNote]
                ),
                mergeMethod: .selectHighestPrecedence,
                issues: entryIssues,
                notes: [stateNote]
            )
            let visibility = ResolvedValue(
                effectiveValue: effectiveState,
                winningSource: winner,
                trace: ResolutionTrace(
                    participants: participants,
                    overridden: overriddenSources,
                    notes: ["Skill visibility computed with project-over-user precedence."]
                ),
                mergeMethod: .selectHighestPrecedence,
                issues: entryIssues,
                notes: ["Skill visibility computed with project-over-user precedence."]
            )
            let isVisible = ResolvedValue(
                effectiveValue: effectiveState.isVisible,
                winningSource: winner,
                trace: visibility.trace,
                mergeMethod: .selectHighestPrecedence,
                issues: entryIssues,
                notes: visibility.notes
            )

            return ResolvedSkillEntry(
                skillID: identity,
                source: source,
                definition: definition,
                visibility: visibility,
                isVisible: isVisible
            )
        }

        return ResolvedSkillSnapshot(
            skills: entries,
            issues: deduplicatedIssues(snapshotIssues),
            notes: [
                "Skill identities are normalized from discovered directory names.",
                "Skill precedence is project over user with deterministic source-id tiebreaks."
            ]
        )
    }

    private func evaluate(_ candidate: SkillDocumentCandidate) -> EvaluatedCandidate {
        var issues = candidate.issues
        issues.append(contentsOf: availabilityIssues(for: candidate.source, subject: "Skill"))

        let identity = skillIdentity(for: candidate)
        if candidate.source.availability == .present, identity == nil {
            issues.append(
                ResolutionIssue(
                    code: .unsupportedShape,
                    severity: .error,
                    message: "Skill directory is missing a usable identity key.",
                    source: candidate.source
                )
            )
        }
        if candidate.source.availability == .present, candidate.document == nil {
            issues.append(
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .error,
                    message: "Skill source is present but did not produce a parsed document.",
                    source: candidate.source
                )
            )
        }
        if candidate.source.availability == .present, candidate.document?.directory.hasSkillMarkdown == false {
            issues.append(
                ResolutionIssue(
                    code: .unsupportedShape,
                    severity: .error,
                    message: "Skill directory is missing SKILL.md and remains discovered but unavailable for effective visibility.",
                    source: candidate.source
                )
            )
        }

        let hasError = issues.contains(where: { $0.severity == .error })
        let state: VisibilityState
        if candidate.source.availability != .present {
            state = .unavailable
        } else if hasError {
            state = .invalid
        } else {
            state = .effective
        }

        return EvaluatedCandidate(
            candidate: candidate,
            identityKey: identity,
            issues: deduplicatedIssues(issues),
            state: state
        )
    }

    private func skillIdentity(for candidate: SkillDocumentCandidate) -> String? {
        if let document = candidate.document {
            let directoryName = document.directory.skillRootURL.lastPathComponent
            if let normalizedDirectory = normalizeIdentity(directoryName), !normalizedDirectory.isEmpty {
                return normalizedDirectory
            }
        }

        if let sourcePath = candidate.source.sourcePath {
            let directoryName = URL(fileURLWithPath: sourcePath).lastPathComponent
            if let normalizedDirectory = normalizeIdentity(directoryName), !normalizedDirectory.isEmpty {
                return normalizedDirectory
            }
        }

        return normalizeIdentity(candidate.source.identifier)
    }

    private func normalizeIdentity(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        let collapsed = components.joined(separator: "-").lowercased()
        return collapsed.isEmpty ? nil : collapsed
    }

    private func sortCandidates(_ candidates: [SkillDocumentCandidate]) -> [SkillDocumentCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.tier != rhs.tier {
                return lhs.tier < rhs.tier
            }
            return lhs.source.id < rhs.source.id
        }
    }

    private func availabilityIssues(for source: ResolutionSource, subject: String) -> [ResolutionIssue] {
        switch source.availability {
        case .present:
            return []
        case .missing:
            return [
                ResolutionIssue(
                    code: .missingSource,
                    severity: .warning,
                    message: "\(subject) source is missing and was skipped.",
                    source: source
                )
            ]
        case .invalid:
            return [
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .error,
                    message: "\(subject) source is invalid and could not contribute definitions.",
                    source: source
                )
            ]
        case .inaccessible:
            return [
                ResolutionIssue(
                    code: .inaccessibleSource,
                    severity: .error,
                    message: "\(subject) source is inaccessible and could not be read.",
                    source: source
                )
            ]
        }
    }

    private func unresolvedIdentity(fallback: String) -> String {
        "unresolved-\(fallback.lowercased())"
    }

    private func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

enum SessionProjectionFamily: String, Equatable, CaseIterable, Sendable {
    case settings
    case instructions
    case hooks
    case mcp
    case agents
    case skills
}

enum SessionFamilyAvailability: String, Equatable, Sendable {
    case available
    case unavailable
}

enum SessionFamilyCompleteness: String, Equatable, Sendable {
    case complete
    case partial
    case unavailable
}

struct ProjectionFamilyState: Equatable, Sendable {
    let family: SessionProjectionFamily
    let availability: SessionFamilyAvailability
    let completeness: SessionFamilyCompleteness
    let totalIssues: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let confidenceNotes: [String]
}

struct SessionIssueFamilySummary: Equatable, Sendable {
    let family: SessionProjectionFamily
    let totalIssues: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
}

struct SessionIssueSummary: Equatable, Sendable {
    let totalIssues: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let byFamily: [SessionIssueFamilySummary]
}

struct SessionCompleteness: Equatable, Sendable {
    let isComplete: Bool
    let missingFamilies: [SessionProjectionFamily]
    let partialFamilies: [SessionProjectionFamily]
    let confidenceNotes: [String]
}

struct SessionProvenanceFamilySummary: Equatable, Sendable {
    let family: SessionProjectionFamily
    let participants: [ResolutionSource]
    let winners: [ResolutionSource]
}

struct SessionProvenanceSummary: Equatable, Sendable {
    let participatingSources: [ResolutionSource]
    let winningSources: [ResolutionSource]
    let byFamily: [SessionProvenanceFamilySummary]
}

struct ResolvedHookEventEntry: Equatable, Sendable {
    let eventID: String
    let eventType: HookEventType
    let hooks: ResolvedValue<[JSONValue]>
}

struct ResolvedHookSnapshot: Equatable, Sendable {
    let events: [ResolvedHookEventEntry]
    let issues: [ResolutionIssue]
    let notes: [String]

    init(events: [ResolvedHookEventEntry], issues: [ResolutionIssue] = [], notes: [String] = []) {
        self.events = events.sorted { lhs, rhs in
            if lhs.eventType.sortKey != rhs.eventType.sortKey {
                return lhs.eventType.sortKey < rhs.eventType.sortKey
            }
            return lhs.eventID < rhs.eventID
        }
        self.issues = issues.sorted { $0.id < $1.id }
        self.notes = notes
    }
}

struct SessionProjection: Equatable, Sendable {
    let settings: ResolvedSettingsSnapshot?
    let instructions: ResolvedInstructionSnapshot?
    let hooks: ResolvedHookSnapshot?
    let mcp: ResolvedMcpSnapshot?
    let agents: ResolvedAgentSnapshot?
    let skills: ResolvedSkillSnapshot?
    let familyStates: [ProjectionFamilyState]
    let issueSummary: SessionIssueSummary
    let completeness: SessionCompleteness
    let provenance: SessionProvenanceSummary
    let issues: [ResolutionIssue]
    let notes: [String]

    init(
        settings: ResolvedSettingsSnapshot? = nil,
        instructions: ResolvedInstructionSnapshot? = nil,
        hooks: ResolvedHookSnapshot? = nil,
        mcp: ResolvedMcpSnapshot? = nil,
        agents: ResolvedAgentSnapshot? = nil,
        skills: ResolvedSkillSnapshot? = nil,
        familyStates: [ProjectionFamilyState] = [],
        issueSummary: SessionIssueSummary? = nil,
        completeness: SessionCompleteness? = nil,
        provenance: SessionProvenanceSummary? = nil,
        issues: [ResolutionIssue] = [],
        notes: [String] = []
    ) {
        self.settings = settings
        self.instructions = instructions
        self.hooks = hooks
        self.mcp = mcp
        self.agents = agents
        self.skills = skills
        self.familyStates = familyStates.sorted { lhs, rhs in
            SessionProjectionFamily.allCases.firstIndex(of: lhs.family) ?? Int.max <
                SessionProjectionFamily.allCases.firstIndex(of: rhs.family) ?? Int.max
        }
        self.issues = issues.sorted { $0.id < $1.id }
        self.issueSummary = issueSummary ?? SessionIssueSummary(
            totalIssues: self.issues.count,
            errorCount: self.issues.filter { $0.severity == .error }.count,
            warningCount: self.issues.filter { $0.severity == .warning }.count,
            infoCount: self.issues.filter { $0.severity == .info }.count,
            byFamily: []
        )
        self.completeness = completeness ?? SessionCompleteness(
            isComplete: false,
            missingFamilies: SessionProjectionFamily.allCases,
            partialFamilies: [],
            confidenceNotes: ["Session projection was initialized without builder-derived completeness metadata."]
        )
        self.provenance = provenance ?? SessionProvenanceSummary(
            participatingSources: [],
            winningSources: [],
            byFamily: []
        )
        self.notes = notes
    }
}

struct SessionProjectionBuilder {
    struct Input: Equatable, Sendable {
        let settings: ResolvedSettingsSnapshot?
        let instructions: ResolvedInstructionSnapshot?
        let mcp: ResolvedMcpSnapshot?
        let agents: ResolvedAgentSnapshot?
        let skills: ResolvedSkillSnapshot?
        let validationIssues: [ValidationIssue]
        let notes: [String]

        init(
            settings: ResolvedSettingsSnapshot? = nil,
            instructions: ResolvedInstructionSnapshot? = nil,
            mcp: ResolvedMcpSnapshot? = nil,
            agents: ResolvedAgentSnapshot? = nil,
            skills: ResolvedSkillSnapshot? = nil,
            validationIssues: [ValidationIssue] = [],
            notes: [String] = []
        ) {
            self.settings = settings
            self.instructions = instructions
            self.mcp = mcp
            self.agents = agents
            self.skills = skills
            self.validationIssues = validationIssues.sorted { $0.id < $1.id }
            self.notes = notes
        }
    }

    func build(from input: Input) -> SessionProjection {
        let hooks = deriveHooks(from: input.settings)

        let settingsIssues = collectSettingsIssues(input.settings)
        let instructionIssues = collectInstructionIssues(input.instructions)
        let hookIssues = collectHookIssues(hooks)
        let mcpIssues = collectMcpIssues(input.mcp)
        let agentIssues = collectAgentIssues(input.agents)
        let skillIssues = collectSkillIssues(input.skills)
        let validationIssues = input.validationIssues.map { $0.asResolutionIssue() }

        let allIssues = deduplicatedIssues(
            settingsIssues +
                instructionIssues +
                hookIssues +
                mcpIssues +
                agentIssues +
                skillIssues +
                validationIssues
        )

        let byFamilyIssues: [(SessionProjectionFamily, [ResolutionIssue])] = [
            (.settings, settingsIssues),
            (.instructions, instructionIssues),
            (.hooks, hookIssues),
            (.mcp, mcpIssues),
            (.agents, agentIssues),
            (.skills, skillIssues)
        ]

        let familyStates = buildFamilyStates(
            input: input,
            hooks: hooks,
            byFamilyIssues: byFamilyIssues
        )
        let issueSummary = buildIssueSummary(byFamilyIssues: byFamilyIssues, totalIssues: allIssues)
        let completeness = buildCompleteness(from: familyStates)
        let provenance = buildProvenance(input: input, hooks: hooks)

        return SessionProjection(
            settings: input.settings,
            instructions: input.instructions,
            hooks: hooks,
            mcp: input.mcp,
            agents: input.agents,
            skills: input.skills,
            familyStates: familyStates,
            issueSummary: issueSummary,
            completeness: completeness,
            provenance: provenance,
            issues: allIssues,
            notes: projectionNotes(input: input, hooks: hooks)
        )
    }

    private func deriveHooks(from settings: ResolvedSettingsSnapshot?) -> ResolvedHookSnapshot? {
        guard let settings else { return nil }
        guard let hookEntry = settings.entries.first(where: { $0.keyPath == "hooks" }) else {
            return nil
        }

        var issues = hookEntry.value.issues
        var notes = hookEntry.value.notes
        var events: [ResolvedHookEventEntry] = []

        guard let rootValue = hookEntry.value.effectiveValue else {
            notes.append("Hooks projection is unresolved because no effective hooks object was selected.")
            return ResolvedHookSnapshot(events: [], issues: deduplicatedIssues(issues), notes: notes)
        }

        guard case let .object(rootObject) = rootValue else {
            issues.append(
                ResolutionIssue(
                    code: .unsupportedShape,
                    severity: .warning,
                    message: "Resolved hooks value must be an object keyed by event identifier.",
                    source: hookEntry.value.winningSource,
                    keyPath: "hooks"
                )
            )
            return ResolvedHookSnapshot(events: [], issues: deduplicatedIssues(issues), notes: notes)
        }

        for eventID in rootObject.keys.sorted() {
            let eventPath = "hooks.\(eventID)"
            guard let rawEventValue = rootObject[eventID] else { continue }
            let eventType = HookEventType(eventName: eventID)

            let extraction = extractHookActions(
                eventID: eventID,
                eventPath: eventPath,
                value: rawEventValue,
                source: hookEntry.value.winningSource
            )

            issues.append(contentsOf: extraction.issues)
            notes.append(contentsOf: extraction.notes)

            let value = ResolvedValue(
                effectiveValue: extraction.actions,
                winningSource: hookEntry.value.winningSource,
                trace: hookEntry.value.trace,
                mergeMethod: .passthrough,
                issues: deduplicatedIssues(hookEntry.value.issues + extraction.issues),
                notes: deduplicatedNotes(hookEntry.value.notes + extraction.notes)
            )
            events.append(ResolvedHookEventEntry(eventID: eventID, eventType: eventType, hooks: value))
        }

        if events.isEmpty {
            notes.append("Resolved settings include a hooks key but no valid hook event entries were produced.")
        } else {
            notes.append("Hooks were derived from the resolved settings 'hooks' object.")
        }

        return ResolvedHookSnapshot(
            events: events,
            issues: deduplicatedIssues(issues),
            notes: deduplicatedNotes(notes)
        )
    }

    private func extractHookActions(
        eventID: String,
        eventPath: String,
        value: JSONValue,
        source: ResolutionSource?
    ) -> (actions: [JSONValue]?, issues: [ResolutionIssue], notes: [String]) {
        switch value {
        case let .array(actions):
            return (
                actions: actions,
                issues: [],
                notes: ["Hooks event '\(eventID)' was loaded from an array value."]
            )
        case let .object(object):
            guard let hookValue = object["hooks"] else {
                return (
                    actions: nil,
                    issues: [
                        ResolutionIssue(
                            code: .unsupportedShape,
                            severity: .warning,
                            message: "Hook event object must include a 'hooks' array.",
                            source: source,
                            keyPath: eventPath
                        )
                    ],
                    notes: ["Hooks event '\(eventID)' is incomplete and did not provide a 'hooks' array."]
                )
            }
            guard case let .array(actions) = hookValue else {
                return (
                    actions: nil,
                    issues: [
                        ResolutionIssue(
                            code: .typeMismatch,
                            severity: .warning,
                            message: "Hook event 'hooks' field must be an array.",
                            source: source,
                            keyPath: "\(eventPath).hooks"
                        )
                    ],
                    notes: ["Hooks event '\(eventID)' had a non-array 'hooks' payload."]
                )
            }
            return (
                actions: actions,
                issues: [],
                notes: ["Hooks event '\(eventID)' was loaded from object.hooks."]
            )
        default:
            return (
                actions: nil,
                issues: [
                    ResolutionIssue(
                        code: .unsupportedShape,
                        severity: .warning,
                        message: "Hook event values must be an array or object with a 'hooks' array.",
                        source: source,
                        keyPath: eventPath
                    )
                ],
                notes: ["Hooks event '\(eventID)' used an unsupported shape and could not be projected."]
            )
        }
    }

    private func collectSettingsIssues(_ settings: ResolvedSettingsSnapshot?) -> [ResolutionIssue] {
        guard let settings else { return [] }
        let nested = settings.entries.flatMap(\.value.issues)
        return deduplicatedIssues(settings.issues + nested)
    }

    private func collectInstructionIssues(_ instructions: ResolvedInstructionSnapshot?) -> [ResolutionIssue] {
        guard let instructions else { return [] }
        let nested = instructions.orderedBlocks.flatMap(\.content.issues) + instructions.composedInstructions.issues
        return deduplicatedIssues(instructions.issues + nested)
    }

    private func collectHookIssues(_ hooks: ResolvedHookSnapshot?) -> [ResolutionIssue] {
        guard let hooks else { return [] }
        let nested = hooks.events.flatMap(\.hooks.issues)
        return deduplicatedIssues(hooks.issues + nested)
    }

    private func collectMcpIssues(_ mcp: ResolvedMcpSnapshot?) -> [ResolutionIssue] {
        guard let mcp else { return [] }
        let nested = mcp.servers.flatMap(\.resolvedConfig.issues)
        return deduplicatedIssues(mcp.issues + nested)
    }

    private func collectAgentIssues(_ agents: ResolvedAgentSnapshot?) -> [ResolutionIssue] {
        guard let agents else { return [] }
        let nested = agents.agents.flatMap { entry in
            entry.definition.issues + entry.visibility.issues + entry.isVisible.issues
        }
        return deduplicatedIssues(agents.issues + nested)
    }

    private func collectSkillIssues(_ skills: ResolvedSkillSnapshot?) -> [ResolutionIssue] {
        guard let skills else { return [] }
        let nested = skills.skills.flatMap { entry in
            entry.definition.issues + entry.visibility.issues + entry.isVisible.issues
        }
        return deduplicatedIssues(skills.issues + nested)
    }

    private func buildFamilyStates(
        input: Input,
        hooks: ResolvedHookSnapshot?,
        byFamilyIssues: [(SessionProjectionFamily, [ResolutionIssue])]
    ) -> [ProjectionFamilyState] {
        let availableByFamily: [SessionProjectionFamily: Bool] = [
            .settings: input.settings != nil,
            .instructions: input.instructions != nil,
            .hooks: hooks != nil,
            .mcp: input.mcp != nil,
            .agents: input.agents != nil,
            .skills: input.skills != nil
        ]
        let notesByFamily: [SessionProjectionFamily: [String]] = [
            .settings: input.settings?.notes ?? [],
            .instructions: input.instructions?.notes ?? [],
            .hooks: hooks?.notes ?? [],
            .mcp: input.mcp?.notes ?? [],
            .agents: input.agents?.notes ?? [],
            .skills: input.skills?.notes ?? []
        ]

        var stateByFamily: [ProjectionFamilyState] = []
        for family in SessionProjectionFamily.allCases {
            let issues = byFamilyIssues.first(where: { $0.0 == family })?.1 ?? []
            let hasError = issues.contains(where: { $0.severity == .error })
            let isAvailable = availableByFamily[family] ?? false
            let completeness: SessionFamilyCompleteness

            if isAvailable == false {
                completeness = .unavailable
            } else if hasError {
                completeness = .partial
            } else {
                completeness = .complete
            }

            stateByFamily.append(
                ProjectionFamilyState(
                    family: family,
                    availability: isAvailable ? .available : .unavailable,
                    completeness: completeness,
                    totalIssues: issues.count,
                    errorCount: issues.filter { $0.severity == .error }.count,
                    warningCount: issues.filter { $0.severity == .warning }.count,
                    infoCount: issues.filter { $0.severity == .info }.count,
                    confidenceNotes: deduplicatedNotes(notesByFamily[family] ?? [])
                )
            )
        }

        return stateByFamily
    }

    private func buildIssueSummary(
        byFamilyIssues: [(SessionProjectionFamily, [ResolutionIssue])],
        totalIssues: [ResolutionIssue]
    ) -> SessionIssueSummary {
        let familyRows = SessionProjectionFamily.allCases.map { family -> SessionIssueFamilySummary in
            let issues = byFamilyIssues.first(where: { $0.0 == family })?.1 ?? []
            return SessionIssueFamilySummary(
                family: family,
                totalIssues: issues.count,
                errorCount: issues.filter { $0.severity == .error }.count,
                warningCount: issues.filter { $0.severity == .warning }.count,
                infoCount: issues.filter { $0.severity == .info }.count
            )
        }

        return SessionIssueSummary(
            totalIssues: totalIssues.count,
            errorCount: totalIssues.filter { $0.severity == .error }.count,
            warningCount: totalIssues.filter { $0.severity == .warning }.count,
            infoCount: totalIssues.filter { $0.severity == .info }.count,
            byFamily: familyRows
        )
    }

    private func buildCompleteness(from familyStates: [ProjectionFamilyState]) -> SessionCompleteness {
        let missing = familyStates
            .filter { $0.availability == .unavailable }
            .map(\.family)
        let partial = familyStates
            .filter { $0.completeness == .partial }
            .map(\.family)

        var confidenceNotes: [String] = []
        if missing.isEmpty {
            confidenceNotes.append("All projection families are available.")
        } else {
            confidenceNotes.append("Projection is missing families: \(missing.map(\.rawValue).joined(separator: ", ")).")
        }
        if partial.isEmpty {
            confidenceNotes.append("No available family is in a partial state.")
        } else {
            confidenceNotes.append("Some available families are partial due to error-level diagnostics.")
        }

        return SessionCompleteness(
            isComplete: missing.isEmpty && partial.isEmpty,
            missingFamilies: missing,
            partialFamilies: partial,
            confidenceNotes: confidenceNotes
        )
    }

    private func buildProvenance(input: Input, hooks: ResolvedHookSnapshot?) -> SessionProvenanceSummary {
        let familyRows: [SessionProvenanceFamilySummary] = [
            provenanceForSettings(input.settings),
            provenanceForInstructions(input.instructions),
            provenanceForHooks(hooks),
            provenanceForMcp(input.mcp),
            provenanceForAgents(input.agents),
            provenanceForSkills(input.skills)
        ]

        let participants = deduplicatedSources(
            familyRows.flatMap(\.participants)
        )
        let winners = deduplicatedSources(
            familyRows.flatMap(\.winners)
        )

        return SessionProvenanceSummary(
            participatingSources: participants,
            winningSources: winners,
            byFamily: familyRows
        )
    }

    private func provenanceForSettings(_ settings: ResolvedSettingsSnapshot?) -> SessionProvenanceFamilySummary {
        let participants = settings?.entries.flatMap { $0.value.trace.participants } ?? []
        let winners = settings?.entries.compactMap { $0.value.winningSource } ?? []
        return SessionProvenanceFamilySummary(
            family: .settings,
            participants: deduplicatedSources(participants),
            winners: deduplicatedSources(winners)
        )
    }

    private func provenanceForInstructions(_ instructions: ResolvedInstructionSnapshot?) -> SessionProvenanceFamilySummary {
        let participants = (instructions?.orderedBlocks.flatMap { $0.content.trace.participants } ?? []) +
            (instructions?.composedInstructions.trace.participants ?? [])
        let winners = (instructions?.orderedBlocks.compactMap { $0.content.winningSource } ?? []) +
            [instructions?.composedInstructions.winningSource].compactMap { $0 }
        return SessionProvenanceFamilySummary(
            family: .instructions,
            participants: deduplicatedSources(participants),
            winners: deduplicatedSources(winners)
        )
    }

    private func provenanceForHooks(_ hooks: ResolvedHookSnapshot?) -> SessionProvenanceFamilySummary {
        let participants = hooks?.events.flatMap { $0.hooks.trace.participants } ?? []
        let winners = hooks?.events.compactMap { $0.hooks.winningSource } ?? []
        return SessionProvenanceFamilySummary(
            family: .hooks,
            participants: deduplicatedSources(participants),
            winners: deduplicatedSources(winners)
        )
    }

    private func provenanceForMcp(_ mcp: ResolvedMcpSnapshot?) -> SessionProvenanceFamilySummary {
        let participants = mcp?.servers.flatMap { $0.resolvedConfig.trace.participants } ?? []
        let winners = mcp?.servers.compactMap { $0.resolvedConfig.winningSource } ?? []
        return SessionProvenanceFamilySummary(
            family: .mcp,
            participants: deduplicatedSources(participants),
            winners: deduplicatedSources(winners)
        )
    }

    private func provenanceForAgents(_ agents: ResolvedAgentSnapshot?) -> SessionProvenanceFamilySummary {
        let participants = agents?.agents.flatMap { $0.definition.trace.participants } ?? []
        let winners = agents?.agents.compactMap { $0.definition.winningSource } ?? []
        return SessionProvenanceFamilySummary(
            family: .agents,
            participants: deduplicatedSources(participants),
            winners: deduplicatedSources(winners)
        )
    }

    private func provenanceForSkills(_ skills: ResolvedSkillSnapshot?) -> SessionProvenanceFamilySummary {
        let participants = skills?.skills.flatMap { $0.definition.trace.participants } ?? []
        let winners = skills?.skills.compactMap { $0.definition.winningSource } ?? []
        return SessionProvenanceFamilySummary(
            family: .skills,
            participants: deduplicatedSources(participants),
            winners: deduplicatedSources(winners)
        )
    }

    private func projectionNotes(input: Input, hooks: ResolvedHookSnapshot?) -> [String] {
        var notes = input.notes
        notes.append("Session projection is computed in-memory and is never persisted as shadow truth.")
        notes.append("Projection collections use deterministic ordering for stable tests and UI.")
        if hooks == nil {
            notes.append("Hooks projection was unavailable because no resolved settings hooks key was present.")
        }
        return deduplicatedNotes(notes)
    }

    private func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }

    private func deduplicatedSources(_ sources: [ResolutionSource]) -> [ResolutionSource] {
        var seen = Set<String>()
        var ordered: [ResolutionSource] = []
        for source in sources.sorted(by: { $0.id < $1.id }) where seen.insert(source.id).inserted {
            ordered.append(source)
        }
        return ordered
    }

    private func deduplicatedNotes(_ notes: [String]) -> [String] {
        var seen = Set<String>()
        return notes.filter { seen.insert($0).inserted }
    }
}

enum ImportTokenParseStatus: Equatable, Sendable {
    case valid
    case malformed
}

struct ParsedImportToken: Equatable, Sendable {
    let rawToken: String
    let rawPath: String?
    let range: SourceRange?
    let status: ImportTokenParseStatus
}

struct ParsedClaudeMdDocument: Equatable, Sendable {
    let source: SourceFileReference
    let rawBody: String
    let imports: [ParsedImportToken]
}

struct ClaudeMdParser {
    func parse(data: Data, sourceURL: URL) -> ParseResult<ParsedClaudeMdDocument> {
        let markdown = String(decoding: data, as: UTF8.self)
        return parse(markdown: markdown, sourceURL: sourceURL)
    }

    func parse(markdown: String, sourceURL: URL) -> ParseResult<ParsedClaudeMdDocument> {
        let source = SourceFileReference(url: sourceURL)
        var tokens: [ParsedImportToken] = []
        var issues: [SyntaxIssue] = []

        let lines = markdown.components(separatedBy: .newlines)
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            let chars = Array(line)
            var i = 0

            while i < chars.count {
                guard chars[i] == "@" else {
                    i += 1
                    continue
                }

                let start = i
                let startColumn = i + 1

                if i + 1 >= chars.count {
                    let token = ParsedImportToken(
                        rawToken: "@",
                        rawPath: nil,
                        range: SourceRange(startLine: lineNumber, startColumn: startColumn, endLine: lineNumber, endColumn: startColumn),
                        status: .malformed
                    )
                    tokens.append(token)
                    issues.append(
                        SyntaxIssue(
                            code: .invalidMarkdownReferenceToken,
                            severity: .warning,
                            message: "Import token '@' is missing a path segment.",
                            sourcePath: source.displayPath,
                            range: token.range
                        )
                    )
                    i += 1
                    continue
                }

                if chars[i + 1].isWhitespace {
                    var end = i + 1
                    while end < chars.count, chars[end].isWhitespace {
                        end += 1
                    }
                    let raw = String(chars[start..<min(end, chars.count)])
                    let token = ParsedImportToken(
                        rawToken: raw,
                        rawPath: nil,
                        range: SourceRange(startLine: lineNumber, startColumn: startColumn, endLine: lineNumber, endColumn: end),
                        status: .malformed
                    )
                    tokens.append(token)
                    issues.append(
                        SyntaxIssue(
                            code: .invalidMarkdownReferenceToken,
                            severity: .warning,
                            message: "Import token has whitespace after '@'. Use '@path/to/file'.",
                            sourcePath: source.displayPath,
                            range: token.range
                        )
                    )
                    i = end
                    continue
                }

                var end = i + 1
                while end < chars.count {
                    let c = chars[end]
                    if c.isWhitespace || c == ")" || c == "]" || c == "}" || c == "," {
                        break
                    }
                    end += 1
                }

                let rawToken = String(chars[start..<end])
                let path = String(chars[(start + 1)..<end])
                let range = SourceRange(startLine: lineNumber, startColumn: startColumn, endLine: lineNumber, endColumn: end)

                if path.isEmpty {
                    let token = ParsedImportToken(rawToken: rawToken, rawPath: nil, range: range, status: .malformed)
                    tokens.append(token)
                    issues.append(
                        SyntaxIssue(
                            code: .invalidMarkdownReferenceToken,
                            severity: .warning,
                            message: "Import token is missing a path segment.",
                            sourcePath: source.displayPath,
                            range: token.range
                        )
                    )
                } else {
                    tokens.append(
                        ParsedImportToken(
                            rawToken: rawToken,
                            rawPath: path,
                            range: range,
                            status: .valid
                        )
                    )
                }

                i = end
            }
        }

        return ParseResult(
            value: ParsedClaudeMdDocument(
                source: source,
                rawBody: markdown,
                imports: tokens
            ),
            issues: issues
        )
    }
}

struct InstructionDocumentCandidate: Equatable, Sendable {
    let source: ResolutionSource
    let document: ParsedClaudeMdDocument?
    let issues: [ResolutionIssue]
}

struct InstructionMemoryCandidate: Equatable, Sendable {
    let topicID: String
    let title: String
    let source: ResolutionSource
    let content: String?
    let issues: [ResolutionIssue]
}

struct InstructionResolverInput: Equatable, Sendable {
    let managed: InstructionDocumentCandidate?
    let user: InstructionDocumentCandidate?
    let project: InstructionDocumentCandidate?
    let projectLocal: InstructionDocumentCandidate?
    let importedDocuments: [InstructionDocumentCandidate]
    let startupMemory: [InstructionMemoryCandidate]
    let onDemandMemory: [InstructionMemoryCandidate]

    init(
        managed: InstructionDocumentCandidate? = nil,
        user: InstructionDocumentCandidate? = nil,
        project: InstructionDocumentCandidate? = nil,
        projectLocal: InstructionDocumentCandidate? = nil,
        importedDocuments: [InstructionDocumentCandidate] = [],
        startupMemory: [InstructionMemoryCandidate] = [],
        onDemandMemory: [InstructionMemoryCandidate] = []
    ) {
        self.managed = managed
        self.user = user
        self.project = project
        self.projectLocal = projectLocal
        self.importedDocuments = importedDocuments
        self.startupMemory = startupMemory
        self.onDemandMemory = onDemandMemory
    }
}

struct InstructionResolver {
    let maxImportDepth: Int

    init(maxImportDepth: Int = 8) {
        self.maxImportDepth = maxImportDepth
    }

    func resolve(_ input: InstructionResolverInput) -> ResolvedInstructionSnapshot {
        let rootCandidates = [input.managed, input.user, input.project, input.projectLocal].compactMap { $0 }
        let roots = rootCandidates.sorted { lhs, rhs in
            let lRank = rootRank(lhs.source.scope)
            let rRank = rootRank(rhs.source.scope)
            if lRank != rRank { return lRank < rRank }
            return lhs.source.id < rhs.source.id
        }

        let allKnown = allCandidates(input)
        let candidatesByPath = Dictionary(uniqueKeysWithValues: allKnown.compactMap { candidate -> (String, InstructionDocumentCandidate)? in
            guard let sourcePath = candidate.source.sourcePath else { return nil }
            return (normalizedPath(sourcePath), candidate)
        })

        var issues: [ResolutionIssue] = []
        var orderedBlocks: [ResolvedInstructionBlock] = []
        var edges: [ResolvedInstructionImportEdge] = []
        var loaded = Set<String>()

        for root in roots {
            traverse(
                candidate: root,
                depth: 0,
                stack: [],
                candidatesByPath: candidatesByPath,
                loaded: &loaded,
                orderedBlocks: &orderedBlocks,
                edges: &edges,
                issues: &issues
            )
        }

        let startupTopics = input.startupMemory
            .map { topic in
                ResolvedInstructionMemoryTopic(
                    topicID: topic.topicID,
                    title: topic.title,
                    source: topic.source,
                    availability: topic.source.availability
                )
            }
        let onDemandTopics = input.onDemandMemory
            .map { topic in
                ResolvedInstructionMemoryTopic(
                    topicID: topic.topicID,
                    title: topic.title,
                    source: topic.source,
                    availability: topic.source.availability
                )
            }

        for topic in input.startupMemory {
            issues.append(contentsOf: topic.issues)
        }
        for topic in input.onDemandMemory {
            issues.append(contentsOf: topic.issues)
        }

        let startupBody = input.startupMemory.compactMap { topic -> String? in
            guard topic.source.availability == .present else { return nil }
            return topic.content
        }

        let bodySegments = orderedBlocks.map { $0.content.effectiveValue ?? "" } + startupBody
        let composedText = bodySegments.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let participants = orderedBlocks.compactMap { $0.content.winningSource } + startupTopics.map(\.source)

        let composed = ResolvedValue(
            effectiveValue: composedText.isEmpty ? nil : composedText,
            winningSource: participants.first,
            trace: ResolutionTrace(participants: participants, overridden: Array(participants.dropFirst())),
            mergeMethod: .append,
            issues: issues
        )

        return ResolvedInstructionSnapshot(
            composedInstructions: composed,
            orderedBlocks: orderedBlocks,
            startupMemoryTopics: startupTopics,
            onDemandMemoryTopics: onDemandTopics,
            importEdges: edges,
            rootLoadOrder: roots.map(\.source),
            issues: issues,
            notes: [
                "Instruction roots resolved in deterministic scope order.",
                "User-authored instructions are resolved separately from auto memory."
            ]
        )
    }

    private func allCandidates(_ input: InstructionResolverInput) -> [InstructionDocumentCandidate] {
        [input.managed, input.user, input.project, input.projectLocal].compactMap { $0 } + input.importedDocuments
    }

    private func rootRank(_ scope: ResolutionScope) -> Int {
        switch scope {
        case .managed:
            return 0
        case .user:
            return 1
        case .project:
            return 2
        case .projectLocal:
            return 3
        default:
            return 99
        }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func resolveImportPath(rawPath: String, parentPath: String?) -> String {
        if rawPath.hasPrefix("/") {
            return normalizedPath(rawPath)
        }
        guard let parentPath else {
            return normalizedPath(rawPath)
        }
        let parentURL = URL(fileURLWithPath: parentPath).deletingLastPathComponent()
        return parentURL.appendingPathComponent(rawPath).standardizedFileURL.path
    }

    private func traverse(
        candidate: InstructionDocumentCandidate,
        depth: Int,
        stack: [String],
        candidatesByPath: [String: InstructionDocumentCandidate],
        loaded: inout Set<String>,
        orderedBlocks: inout [ResolvedInstructionBlock],
        edges: inout [ResolvedInstructionImportEdge],
        issues: inout [ResolutionIssue]
    ) {
        issues.append(contentsOf: candidate.issues)
        guard candidate.source.availability == .present else {
            issues.append(unavailableIssue(for: candidate.source))
            return
        }
        guard let document = candidate.document else {
            issues.append(
                ResolutionIssue(
                    code: .invalidSource,
                    severity: .error,
                    message: "Instruction source has no parsed document content.",
                    source: candidate.source
                )
            )
            return
        }

        let canonicalPath = normalizedPath(candidate.source.sourcePath ?? candidate.source.identifier)
        if stack.contains(canonicalPath) {
            let related = stack.compactMap { candidatesByPath[$0]?.source } + [candidate.source]
            issues.append(
                ResolutionIssue(
                    code: .cycleDetected,
                    severity: .error,
                    message: "Instruction import cycle detected.",
                    source: candidate.source,
                    relatedSources: related
                )
            )
            return
        }

        if !loaded.contains(canonicalPath) {
            let parseIssues = parserIssues(document: document, source: candidate.source)
            issues.append(contentsOf: parseIssues)
            let content = ResolvedValue(
                effectiveValue: document.rawBody,
                winningSource: candidate.source,
                trace: ResolutionTrace(participants: [candidate.source]),
                mergeMethod: .append,
                issues: parseIssues
            )
            orderedBlocks.append(
                ResolvedInstructionBlock(
                    blockID: canonicalPath,
                    content: content
                )
            )
            loaded.insert(canonicalPath)
        }

        for token in document.imports {
            guard token.status == .valid, let rawPath = token.rawPath else {
                issues.append(
                    ResolutionIssue(
                        code: .parserSyntaxIssue,
                        severity: .warning,
                        message: "Malformed import token was ignored during resolution.",
                        source: candidate.source,
                        range: token.range,
                        underlyingParserCode: SyntaxIssueCode.invalidMarkdownReferenceToken.rawValue
                    )
                )
                continue
            }

            let targetPath = resolveImportPath(rawPath: rawPath, parentPath: candidate.source.sourcePath)
            if depth + 1 > maxImportDepth {
                edges.append(
                    ResolvedInstructionImportEdge(
                        parentBlockID: canonicalPath,
                        childBlockID: nil,
                        rawToken: token.rawToken,
                        tokenRange: token.range,
                        resolvedPath: targetPath,
                        depth: depth + 1,
                        isCycle: false
                    )
                )
                issues.append(
                    ResolutionIssue(
                        code: .importDepthExceeded,
                        severity: .warning,
                        message: "Instruction import depth exceeded maximum allowed depth of \(maxImportDepth).",
                        source: candidate.source,
                        relatedSources: [candidate.source]
                    )
                )
                continue
            }

            guard let targetCandidate = candidatesByPath[targetPath] else {
                edges.append(
                    ResolvedInstructionImportEdge(
                        parentBlockID: canonicalPath,
                        childBlockID: nil,
                        rawToken: token.rawToken,
                        tokenRange: token.range,
                        resolvedPath: targetPath,
                        depth: depth + 1,
                        isCycle: false
                    )
                )
                issues.append(
                    ResolutionIssue(
                        code: .unresolvedImport,
                        severity: .warning,
                        message: "Instruction import target could not be found: \(targetPath)",
                        source: candidate.source,
                        relatedSources: [candidate.source]
                    )
                )
                continue
            }

            let targetCanonicalPath = normalizedPath(targetCandidate.source.sourcePath ?? targetCandidate.source.identifier)
            let wouldCycle = stack.contains(targetCanonicalPath) || canonicalPath == targetCanonicalPath
            edges.append(
                ResolvedInstructionImportEdge(
                    parentBlockID: canonicalPath,
                    childBlockID: targetCanonicalPath,
                    rawToken: token.rawToken,
                    tokenRange: token.range,
                    resolvedPath: targetPath,
                    depth: depth + 1,
                    isCycle: wouldCycle
                )
            )

            if wouldCycle {
                issues.append(
                    ResolutionIssue(
                        code: .cycleDetected,
                        severity: .error,
                        message: "Instruction import cycle detected.",
                        source: candidate.source,
                        relatedSources: [candidate.source, targetCandidate.source]
                    )
                )
                continue
            }

            traverse(
                candidate: targetCandidate,
                depth: depth + 1,
                stack: stack + [canonicalPath],
                candidatesByPath: candidatesByPath,
                loaded: &loaded,
                orderedBlocks: &orderedBlocks,
                edges: &edges,
                issues: &issues
            )
        }
    }

    private func parserIssues(document: ParsedClaudeMdDocument, source: ResolutionSource) -> [ResolutionIssue] {
        document.imports.compactMap { token in
            guard token.status == .malformed else { return nil }
            return ResolutionIssue(
                code: .parserSyntaxIssue,
                severity: .warning,
                message: "Malformed import token in instruction markdown.",
                source: source,
                range: token.range,
                underlyingParserCode: SyntaxIssueCode.invalidMarkdownReferenceToken.rawValue
            )
        }
    }

    private func unavailableIssue(for source: ResolutionSource) -> ResolutionIssue {
        switch source.availability {
        case .present:
            return ResolutionIssue(
                code: .note,
                severity: .info,
                message: "Instruction source was present."
            )
        case .missing:
            return ResolutionIssue(
                code: .missingSource,
                severity: .warning,
                message: "Instruction source is missing and was skipped.",
                source: source
            )
        case .invalid:
            return ResolutionIssue(
                code: .invalidSource,
                severity: .error,
                message: "Instruction source is invalid and was skipped.",
                source: source
            )
        case .inaccessible:
            return ResolutionIssue(
                code: .inaccessibleSource,
                severity: .error,
                message: "Instruction source is inaccessible and was skipped.",
                source: source
            )
        }
    }
}
