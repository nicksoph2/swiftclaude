import Foundation
import os

// MARK: - Supporting Types

enum PipelineState: Equatable, Sendable {
    case idle
    case running
    case completed
    case failed(Error)

    static func == (lhs: PipelineState, rhs: PipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.running, .running):
            return true
        case (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

enum ConfigFileType: String {
    case settings
    case claudeJson
    case agent
    case skill
    case claudeMd
    case mcpJson
}

struct ParseResultRecord: Identifiable {
    let id: String
    let sourceFile: URL
    let scope: ResolutionScope
    let fileType: ConfigFileType
    let parseIssues: [SyntaxIssue]
    let rawContent: JSONValue?
    let rawTextContent: String?

    // Typed parsed documents — populated by the parse step
    var parsedSettings: ParsedSettingsDocument?
    var parsedAgent: ParsedAgentDocument?
    var parsedSkill: ParsedSkillDocument?
    var parsedClaudeMd: ParsedClaudeMdDocument?
}

// MARK: - Configuration Pipeline

@MainActor
final class ConfigurationPipeline: ObservableObject {
    @Published private(set) var pipelineState: PipelineState = .idle
    @Published private(set) var scanResult: ScanResult?
    @Published private(set) var parseResults: [ParseResultRecord] = []
    @Published private(set) var projection: SessionProjection?
    @Published private(set) var semanticIssues: [ValidationIssue] = []

    private let workspaceScanner: WorkspaceScanner
    private let rootLocator: RootLocator
    private let managedSettingsLocator: ManagedSettingsLocator
    private let settingsParser: SettingsParser
    private let claudeJsonParser: ClaudeJsonParser
    private let agentParser: AgentParser
    private let skillParser: SkillParser
    private let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "Pipeline")

    private var lastGlobalRootURL: URL?
    private var lastProjectRootURLs: [URL] = []

    init(
        workspaceScanner: WorkspaceScanner? = nil,
        rootLocator: RootLocator? = nil,
        managedSettingsLocator: ManagedSettingsLocator = ManagedSettingsLocator(),
        settingsParser: SettingsParser = SettingsParser(),
        claudeJsonParser: ClaudeJsonParser = ClaudeJsonParser(),
        agentParser: AgentParser = AgentParser(),
        skillParser: SkillParser = SkillParser()
    ) {
        self.workspaceScanner = workspaceScanner ?? WorkspaceScanner(managedSettingsLocator: managedSettingsLocator)
        self.rootLocator = rootLocator ?? RootLocator(bookmarkResolver: nil)
        self.managedSettingsLocator = managedSettingsLocator
        self.settingsParser = settingsParser
        self.claudeJsonParser = claudeJsonParser
        self.agentParser = agentParser
        self.skillParser = skillParser
    }

    func run(globalRootURL: URL?, projectRootURLs: [URL]) async {
        pipelineState = .running
        lastGlobalRootURL = globalRootURL
        lastProjectRootURLs = projectRootURLs

        // Phase 1: Discovery
        let scanRequest = buildScanRequest(globalRootURL: globalRootURL, projectRootURLs: projectRootURLs)
        let scanResult = workspaceScanner.scan(scanRequest)
        self.scanResult = scanResult

        // Phase 2: Parsing
        let parseResults = parseDiscoveredFiles(scanResult)
        self.parseResults = parseResults

        // Phase 3: Building resolver inputs
        let (settings, mcp, agents, skills, instructions) = buildResolverInputs(parseResults)

        // Phase 4: Running resolvers
        let (settingsSnapshot, _, mcpSnapshot, agentSnapshot, skillSnapshot, instructionSnapshot) =
            runResolvers(settings: settings, mcp: mcp, agents: agents, skills: skills, instructions: instructions)

        // Phase 5: Building projection
        let builderInput = SessionProjectionBuilder.Input(
            settings: settingsSnapshot,
            instructions: instructionSnapshot,
            mcp: mcpSnapshot,
            agents: agentSnapshot,
            skills: skillSnapshot,
            validationIssues: [],
            notes: []
        )
        let projection = SessionProjectionBuilder().build(from: builderInput)
        self.projection = projection

        // Phase 6: Semantic validation
        let semanticValidator = SemanticValidator()
        let semanticContext = SemanticValidationContext(
            settings: settingsSnapshot,
            instructions: instructionSnapshot,
            mcp: mcpSnapshot,
            agents: agentSnapshot,
            skills: skillSnapshot,
            existingIssues: []
        )
        let semanticResult = semanticValidator.validate(context: semanticContext)
        self.semanticIssues = semanticResult.issues

        pipelineState = .completed
        logger.info("Pipeline completed successfully")
    }

    func refresh() async {
        await run(globalRootURL: lastGlobalRootURL, projectRootURLs: lastProjectRootURLs)
    }

    // MARK: - Private Methods

    private func buildScanRequest(globalRootURL: URL?, projectRootURLs: [URL]) -> ScanRequest {
        // Note: RootLocator should be used to build the actual RootResolutionResult
        // For now, we create a minimal root resolution
        let projectRefs = projectRootURLs.map { url in
            ProjectRootReference(
                id: UUID().uuidString,
                displayName: url.lastPathComponent,
                preferredPath: url.path,
                normalizedPath: RootLocator.normalizedIdentityPath(url.path)
            )
        }

        let projectRoots = projectRefs.map { ref in
            ResolvedProjectRoot(
                reference: ref,
                rootURL: URL(fileURLWithPath: ref.preferredPath),
                accessStatus: .accessible
            )
        }

        let globalRoot = ResolvedGlobalRoot(
            source: globalRootURL != nil ? .overrideBookmark : .defaultHomeClaude,
            rootURL: globalRootURL,
            normalizedPath: globalRootURL.map { RootLocator.normalizedIdentityPath($0.path) },
            accessStatus: globalRootURL != nil ? .accessible : .missing,
            explanation: globalRootURL != nil ? "Global root is set" : "Global root not selected"
        )

        let rootResolution = RootResolutionResult(
            globalRoot: globalRoot,
            projectRoots: projectRoots,
            issues: []
        )

        return ScanRequest(rootResolution: rootResolution)
    }

    private func parseDiscoveredFiles(_ scanResult: ScanResult) -> [ParseResultRecord] {
        var results: [ParseResultRecord] = []

        // Parse managed files
        if let managedWorkspace = scanResult.managedWorkspace {
            results.append(contentsOf: parseWorkspaceFiles(managedWorkspace))
        }

        // Parse user files
        if let userWorkspace = scanResult.userWorkspace {
            results.append(contentsOf: parseWorkspaceFiles(userWorkspace))
        }

        // Parse project files
        for projectWorkspace in scanResult.projectWorkspaces {
            results.append(contentsOf: parseWorkspaceFiles(projectWorkspace))
        }

        return results
    }

    private func parseWorkspaceFiles(_ workspace: DiscoveredWorkspace) -> [ParseResultRecord] {
        var results: [ParseResultRecord] = []

        for file in workspace.files {
            // Skip files that aren't readable
            guard file.status == .present else {
                let parseResult = ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: mapDiscoveryScopeToResolutionScope(workspace.scope),
                    fileType: mapDiscoveredFileKindToConfigFileType(file.kind),
                    parseIssues: [],
                    rawContent: nil,
                    rawTextContent: nil
                )
                results.append(parseResult)
                continue
            }

            let parseResult = parseFile(file, scope: workspace.scope)
            results.append(parseResult)
        }

        return results
    }

    private func parseFile(_ file: DiscoveredFile, scope: DiscoveryScopeIdentity) -> ParseResultRecord {
        let configFileType = mapDiscoveredFileKindToConfigFileType(file.kind)
        let resolutionScope: ResolutionScope
        if file.kind == .projectSettingsLocalJSON {
            resolutionScope = .projectLocal
        } else {
            resolutionScope = mapDiscoveryScopeToResolutionScope(scope)
        }

        do {
            let data = try Data(contentsOf: file.url)

            switch file.kind {
            case .managedSettingsJSON, .userSettingsJSON, .projectSettingsJSON, .projectSettingsLocalJSON:
                let parseResult = settingsParser.parse(data: data, sourceURL: file.url, scope: resolutionScope)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: configFileType,
                    parseIssues: parseResult.issues,
                    rawContent: parseResult.value.map { .object($0.rawTopLevelObject) },
                    rawTextContent: nil,
                    parsedSettings: parseResult.value
                )

            case .userClaudeJSON:
                let parseResult = claudeJsonParser.parse(data: data, sourceURL: file.url)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: configFileType,
                    parseIssues: parseResult.issues,
                    rawContent: parseResult.value.map { .object($0.rawTopLevelObject) },
                    rawTextContent: nil
                )

            case .managedMcpJSON, .projectMCPJSON:
                // MCP files are parsed as raw JSON for now
                let decoder = JSONDecoder()
                let parsed = try decoder.decode(JSONValue.self, from: data)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: configFileType,
                    parseIssues: [],
                    rawContent: parsed,
                    rawTextContent: nil
                )

            case .userAgentMarkdown, .projectAgentMarkdown:
                let parseResult = agentParser.parse(data: data, sourceURL: file.url)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: configFileType,
                    parseIssues: parseResult.issues,
                    rawContent: nil,
                    rawTextContent: parseResult.value?.promptBody,
                    parsedAgent: parseResult.value
                )

            case .userSkillDefinition, .projectSkillDefinition:
                // For skills, we need the directory URL, not just the file
                let skillDirectoryURL = file.url.deletingLastPathComponent()
                let content = String(data: data, encoding: .utf8) ?? ""
                let parseResult = skillParser.parse(skillDirectoryURL: skillDirectoryURL, skillMarkdownData: data)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: configFileType,
                    parseIssues: parseResult.issues,
                    rawContent: nil,
                    rawTextContent: content,
                    parsedSkill: parseResult.value
                )

            case .managedClaudeMarkdown, .userClaudeMarkdown, .projectClaudeMarkdown, .projectClaudeDotMarkdown:
                let content = String(data: data, encoding: .utf8) ?? ""
                let claudeMdParser = ClaudeMdParser()
                let claudeMdResult = claudeMdParser.parse(data: data, sourceURL: file.url)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: .claudeMd,
                    parseIssues: claudeMdResult.issues,
                    rawContent: nil,
                    rawTextContent: content,
                    parsedClaudeMd: claudeMdResult.value
                )

            case .managedSettingsDropIn:
                let parseResult = settingsParser.parse(data: data, sourceURL: file.url, scope: resolutionScope)
                return ParseResultRecord(
                    id: file.id.rawValue,
                    sourceFile: file.url,
                    scope: resolutionScope,
                    fileType: configFileType,
                    parseIssues: parseResult.issues,
                    rawContent: parseResult.value.map { .object($0.rawTopLevelObject) },
                    rawTextContent: nil,
                    parsedSettings: parseResult.value
                )
            }
        } catch {
            logger.error("Failed to parse file at \(file.url.path): \(String(describing: error), privacy: .public)")
            return ParseResultRecord(
                id: file.id.rawValue,
                sourceFile: file.url,
                scope: resolutionScope,
                fileType: configFileType,
                parseIssues: [
                    SyntaxIssue(
                        code: .invalidJSON,
                        severity: .error,
                        message: "Failed to read or parse file: \(error.localizedDescription)",
                        sourcePath: file.url.path,
                        keyPath: nil,
                        range: nil
                    )
                ],
                rawContent: nil,
                rawTextContent: nil
            )
        }
    }

    private func buildResolverInputs(_ parseResults: [ParseResultRecord]) -> (
        settings: [SettingsSourceCandidate],
        mcp: [McpSourceCandidate],
        agents: [AgentDocumentCandidate],
        skills: [SkillDocumentCandidate],
        instructions: InstructionResolverInput
    ) {
        var settingsCandidates: [SettingsSourceCandidate] = []
        var mcpCandidates: [McpSourceCandidate] = []
        var agentCandidates: [AgentDocumentCandidate] = []
        var skillCandidates: [SkillDocumentCandidate] = []

        var managedInstruction: InstructionDocumentCandidate?
        var userInstruction: InstructionDocumentCandidate?
        var projectInstruction: InstructionDocumentCandidate?
        var projectLocalInstruction: InstructionDocumentCandidate?

        for (index, record) in parseResults.enumerated() {
            switch record.fileType {
            case .settings:
                // Map scope to tier
                let tier: SettingsSourceTier = mapScopeToSettingsTier(record.scope)
                let source = ResolutionSource(
                    scope: record.scope,
                    kind: .file,
                    identifier: record.sourceFile.lastPathComponent,
                    displayName: record.sourceFile.path,
                    sourcePath: record.sourceFile.path
                )
                settingsCandidates.append(SettingsSourceCandidate(
                    tier: tier,
                    precedenceRank: index,
                    source: source,
                    document: record.parsedSettings,
                    issues: record.parseIssues.map { syntaxIssue in
                        ResolutionIssue(syntaxIssue: syntaxIssue, source: source)
                    }
                ))

            case .mcpJson:
                let mcpTier: McpSourceTier
                switch record.scope {
                case .managed:
                    mcpTier = .managed
                case .user:
                    mcpTier = .user
                case .project:
                    mcpTier = .project
                case .projectLocal:
                    mcpTier = .local
                default:
                    mcpTier = .user
                }

                // Extract individual server entries from the mcpServers object
                if case .object(let topLevel) = record.rawContent,
                   case .object(let servers)? = topLevel["mcpServers"] {
                    for (serverID, serverConfig) in servers {
                        let source = ResolutionSource(
                            scope: record.scope,
                            kind: .file,
                            identifier: serverID,
                            displayName: record.sourceFile.path,
                            sourcePath: record.sourceFile.path
                        )
                        mcpCandidates.append(McpSourceCandidate(
                            tier: mcpTier,
                            source: source,
                            serverID: serverID,
                            rawConfig: serverConfig,
                            parseOrder: index,
                            issues: record.parseIssues.map { syntaxIssue in
                                ResolutionIssue(syntaxIssue: syntaxIssue, source: source)
                            }
                        ))
                    }
                }

            case .agent:
                if record.parsedAgent != nil || record.rawTextContent != nil {
                    let tier: AgentSourceTier = record.scope == .project ? .project : .user
                    let source = ResolutionSource(
                        scope: record.scope,
                        kind: .file,
                        identifier: record.sourceFile.lastPathComponent,
                        displayName: record.sourceFile.path,
                        sourcePath: record.sourceFile.path
                    )
                    agentCandidates.append(AgentDocumentCandidate(
                        tier: tier,
                        source: source,
                        document: record.parsedAgent,
                        issues: record.parseIssues.map { syntaxIssue in
                            ResolutionIssue(syntaxIssue: syntaxIssue, source: source)
                        }
                    ))
                }

            case .skill:
                if record.parsedSkill != nil || record.rawTextContent != nil {
                    let tier: SkillSourceTier = record.scope == .project ? .project : .user
                    let source = ResolutionSource(
                        scope: record.scope,
                        kind: .file,
                        identifier: record.sourceFile.lastPathComponent,
                        displayName: record.sourceFile.path,
                        sourcePath: record.sourceFile.path
                    )
                    skillCandidates.append(SkillDocumentCandidate(
                        tier: tier,
                        source: source,
                        document: record.parsedSkill,
                        issues: record.parseIssues.map { syntaxIssue in
                            ResolutionIssue(syntaxIssue: syntaxIssue, source: source)
                        }
                    ))
                }

            case .claudeMd:
                if record.parsedClaudeMd != nil || record.rawTextContent != nil {
                    let source = ResolutionSource(
                        scope: record.scope,
                        kind: .file,
                        identifier: record.sourceFile.lastPathComponent,
                        displayName: record.sourceFile.path,
                        sourcePath: record.sourceFile.path
                    )
                    let candidate = InstructionDocumentCandidate(
                        source: source,
                        document: record.parsedClaudeMd,
                        issues: record.parseIssues.map { syntaxIssue in
                            ResolutionIssue(syntaxIssue: syntaxIssue, source: source)
                        }
                    )

                    // Assign to appropriate scope
                    switch record.scope {
                    case .managed:
                        managedInstruction = candidate
                    case .user:
                        userInstruction = candidate
                    case .project:
                        projectInstruction = candidate
                    case .projectLocal:
                        projectLocalInstruction = candidate
                    default:
                        break
                    }
                }

            case .claudeJson:
                break // Handled separately as global config, not part of Session projection
            }
        }

        let instructionInput = InstructionResolverInput(
            managed: managedInstruction,
            user: userInstruction,
            project: projectInstruction,
            projectLocal: projectLocalInstruction,
            importedDocuments: [],
            startupMemory: [],
            onDemandMemory: []
        )

        return (settingsCandidates, mcpCandidates, agentCandidates, skillCandidates, instructionInput)
    }

    private func runResolvers(
        settings: [SettingsSourceCandidate],
        mcp: [McpSourceCandidate],
        agents: [AgentDocumentCandidate],
        skills: [SkillDocumentCandidate],
        instructions: InstructionResolverInput
    ) -> (
        settings: ResolvedSettingsSnapshot?,
        hooks: ResolvedHookSnapshot?,
        mcp: ResolvedMcpSnapshot?,
        agents: ResolvedAgentSnapshot?,
        skills: ResolvedSkillSnapshot?,
        instructions: ResolvedInstructionSnapshot?
    ) {
        // Settings resolver
        let settingsResolver = SettingsResolver()
        let settingsPrecedence = settingsResolver.resolvePrecedence(candidates: settings)
        let settingsSnapshot = settingsResolver.buildSnapshot(from: settingsPrecedence)

        // Hook resolver
        let hookResolver = HookResolver()
        let hookInput = HookResolver.Input(resolvedSettings: settingsSnapshot)
        let hookSnapshot = hookResolver.resolve(from: hookInput)

        // MCP resolver
        let mcpResolver = MCPResolver()
        let mcpSnapshot = mcpResolver.resolve(candidates: mcp)

        // Agent resolver
        let agentResolver = AgentResolver()
        let agentSnapshot = agentResolver.resolve(candidates: agents)

        // Skill resolver
        let skillResolver = SkillResolver()
        let skillSnapshot = skillResolver.resolve(candidates: skills)

        // Instruction resolver
        let instructionResolver = InstructionResolver()
        let instructionSnapshot = instructionResolver.resolve(instructions)

        return (settingsSnapshot, hookSnapshot, mcpSnapshot, agentSnapshot, skillSnapshot, instructionSnapshot)
    }

    // MARK: - Mapping Helpers

    private func mapDiscoveryScopeToResolutionScope(_ scope: DiscoveryScopeIdentity) -> ResolutionScope {
        switch scope.scopeKind {
        case .managed:
            return .managed
        case .user:
            return .user
        case .project:
            return .project
        }
    }

    private func mapDiscoveredFileKindToConfigFileType(_ kind: DiscoveredFileKind) -> ConfigFileType {
        switch kind {
        case .managedSettingsJSON, .userSettingsJSON, .projectSettingsJSON, .projectSettingsLocalJSON:
            return .settings
        case .userClaudeJSON:
            return .claudeJson
        case .userAgentMarkdown, .projectAgentMarkdown:
            return .agent
        case .userSkillDefinition, .projectSkillDefinition:
            return .skill
        case .managedClaudeMarkdown, .userClaudeMarkdown, .projectClaudeMarkdown, .projectClaudeDotMarkdown:
            return .claudeMd
        case .managedMcpJSON, .projectMCPJSON:
            return .mcpJson
        case .managedSettingsDropIn:
            return .settings
        }
    }

    private func mapScopeToSettingsTier(_ scope: ResolutionScope) -> SettingsSourceTier {
        switch scope {
        case .managed:
            return .managed
        case .user:
            return .user
        case .project:
            return .projectShared
        case .projectLocal:
            return .projectLocal
        case .cli:
            return .cli
        default:
            return .user
        }
    }
}
