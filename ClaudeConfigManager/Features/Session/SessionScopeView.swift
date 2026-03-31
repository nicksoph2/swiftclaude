import SwiftUI

struct SessionScopeView: View {
    private enum SessionPanel: String, CaseIterable, Identifiable {
        case settings
        case instructions
        case hooks
        case mcp
        case agentsSkills

        var id: String { rawValue }

        var title: String {
            switch self {
            case .settings:
                return "Settings"
            case .instructions:
                return "Instructions"
            case .hooks:
                return "Hooks"
            case .mcp:
                return "MCP"
            case .agentsSkills:
                return "Agents & Skills"
            }
        }
    }

    @EnvironmentObject private var debugMonitor: AppDebugMonitor
    @State private var selectedPanel: SessionPanel = .settings

    private let projection: SessionProjection

    init(projection: SessionProjection = SessionScopeView.previewProjection) {
        self.projection = projection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Session Panel", selection: $selectedPanel) {
                ForEach(SessionPanel.allCases) { panel in
                    Text(panel.title).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            switch selectedPanel {
            case .settings:
                SessionSettingsView(viewModel: SessionSettingsViewModel(projection: projection))
            case .instructions:
                SessionInstructionsView(viewModel: SessionInstructionsViewModel(projection: projection))
            case .hooks:
                SessionHooksView(viewModel: SessionHooksViewModel(projection: projection))
            case .mcp:
                SessionMCPView(viewModel: SessionMCPViewModel(projection: projection))
            case .agentsSkills:
                SessionAgentsSkillsView(viewModel: SessionAgentsSkillsViewModel(projection: projection))
            }
        }
        .onAppear {
            debugMonitor.recordDetail(
                title: "Session",
                subtitle: "Read-only effective settings, instructions, hooks, and MCP state with provenance.",
                debugNotes: [
                    "Projection-driven settings view (F1).",
                    "Projection-driven instructions view (F2).",
                    "Projection-driven hooks view (F3).",
                    "Projection-driven MCP view (F4).",
                    "Settings availability: \(projection.familyStates.first(where: { $0.family == .settings })?.availability.rawValue ?? "unknown")",
                    "Instructions availability: \(projection.familyStates.first(where: { $0.family == .instructions })?.availability.rawValue ?? "unknown")",
                    "Hooks availability: \(projection.familyStates.first(where: { $0.family == .hooks })?.availability.rawValue ?? "unknown")",
                    "MCP availability: \(projection.familyStates.first(where: { $0.family == .mcp })?.availability.rawValue ?? "unknown")",
                    "Agents availability: \(projection.familyStates.first(where: { $0.family == .agents })?.availability.rawValue ?? "unknown")",
                    "Skills availability: \(projection.familyStates.first(where: { $0.family == .skills })?.availability.rawValue ?? "unknown")",
                    "Total projection issues: \(projection.issueSummary.totalIssues)"
                ]
            )
        }
        .navigationTitle("Session")
    }

    private static let previewProjection: SessionProjection = {
        let userSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-settings",
            displayName: "~/.claude/settings.json",
            sourcePath: "/Users/example/.claude/settings.json"
        )
        let projectLocalSource = ResolutionSource(
            scope: .projectLocal,
            kind: .file,
            identifier: "project-local-settings",
            displayName: ".claude/settings.local.json",
            sourcePath: "/Users/example/workspace/.claude/settings.local.json"
        )

        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "cleanupPeriodDays",
                    value: ResolvedValue(
                        effectiveValue: .number(14),
                        winningSource: projectLocalSource,
                        trace: ResolutionTrace(
                            participants: [projectLocalSource, userSource],
                            overridden: [userSource],
                            notes: ["Selected highest-precedence value from project-local settings."]
                        ),
                        mergeMethod: .replace,
                        notes: ["Scalar setting merged by replacement."]
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "env",
                    value: ResolvedValue(
                        effectiveValue: .object([
                            "PATH": .string("/usr/local/bin"),
                            "NODE_ENV": .string("development")
                        ]),
                        winningSource: projectLocalSource,
                        trace: ResolutionTrace(
                            participants: [projectLocalSource, userSource],
                            overridden: [userSource],
                            notes: ["Object key merged with high-precedence child overrides."]
                        ),
                        mergeMethod: .deepMergeObject
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "allowManagedHooksOnly",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: projectLocalSource,
                        trace: ResolutionTrace(
                            participants: [projectLocalSource, userSource],
                            overridden: [userSource],
                            notes: ["Managed-only hooks policy was enforced by project-local settings."]
                        ),
                        mergeMethod: .replace,
                        notes: ["Policy constraint contributes to Session hooks restrictions."]
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "allowedHttpHookUrls",
                    value: ResolvedValue(
                        effectiveValue: .array([.string("https://hooks.example.internal/*")]),
                        winningSource: projectLocalSource,
                        trace: ResolutionTrace(
                            participants: [projectLocalSource],
                            notes: ["HTTP hook URL allowlist configured at project-local scope."]
                        ),
                        mergeMethod: .appendUnique
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object([
                            "preToolUse": .object([
                                "matcher": .string("Bash"),
                                "hooks": .array([
                                    .object([
                                        "type": .string("command"),
                                        "command": .string("echo validating command"),
                                        "timeout": .number(15)
                                    ])
                                ])
                            ]),
                            "postToolUse": .array([
                                .object([
                                    "type": .string("http"),
                                    "url": .string("https://hooks.example.internal/post-tool"),
                                    "timeout": .number(30)
                                ])
                            ])
                        ]),
                        winningSource: projectLocalSource,
                        trace: ResolutionTrace(
                            participants: [projectLocalSource, userSource],
                            overridden: [userSource],
                            notes: ["Hooks merged by event and action identity."]
                        ),
                        mergeMethod: .keyedByIdentifier,
                        notes: ["Preview fixture: includes matcher and mixed action transport types."]
                    )
                )
            ],
            notes: ["Preview fixture: Session UI is projection-driven and read-only."]
        )

        let managedInstructionSource = ResolutionSource(
            scope: .managed,
            kind: .file,
            identifier: "managed-claude-md",
            displayName: "Managed CLAUDE.md",
            sourcePath: "/Managed/CLAUDE.md"
        )
        let userInstructionSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-claude-md",
            displayName: "~/.claude/CLAUDE.md",
            sourcePath: "/Users/example/.claude/CLAUDE.md"
        )
        let importedInstructionSource = ResolutionSource(
            scope: .imported,
            kind: .imported,
            identifier: "shared-guidelines",
            displayName: "shared/guidelines.md",
            sourcePath: "/Users/example/workspace/docs/guidelines.md"
        )
        let startupMemorySource = ResolutionSource(
            scope: .autoMemory,
            kind: .autoMemory,
            identifier: "memory-startup-team",
            displayName: "Team preferences",
            sourcePath: "/Users/example/.claude/projects/workspace/memory/startup/team.md"
        )
        let onDemandMemorySource = ResolutionSource(
            scope: .autoMemory,
            kind: .autoMemory,
            identifier: "memory-topic-release",
            displayName: "Release process",
            sourcePath: "/Users/example/.claude/projects/workspace/memory/topics/release.md"
        )

        let instructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: """
                Managed instruction body.

                User instruction body.

                Imported instruction body.
                """,
                winningSource: managedInstructionSource,
                trace: ResolutionTrace(
                    participants: [managedInstructionSource, userInstructionSource, importedInstructionSource],
                    overridden: [userInstructionSource, importedInstructionSource]
                ),
                mergeMethod: .append
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(
                    blockID: managedInstructionSource.sourcePath ?? "managed",
                    content: ResolvedValue(
                        effectiveValue: "Managed instruction body.",
                        winningSource: managedInstructionSource,
                        trace: ResolutionTrace(participants: [managedInstructionSource]),
                        mergeMethod: .append
                    )
                ),
                ResolvedInstructionBlock(
                    blockID: userInstructionSource.sourcePath ?? "user",
                    content: ResolvedValue(
                        effectiveValue: "User instruction body.",
                        winningSource: userInstructionSource,
                        trace: ResolutionTrace(participants: [userInstructionSource]),
                        mergeMethod: .append
                    )
                ),
                ResolvedInstructionBlock(
                    blockID: importedInstructionSource.sourcePath ?? "imported",
                    content: ResolvedValue(
                        effectiveValue: "Imported instruction body.",
                        winningSource: importedInstructionSource,
                        trace: ResolutionTrace(participants: [importedInstructionSource]),
                        mergeMethod: .append
                    )
                )
            ],
            startupMemoryTopics: [
                ResolvedInstructionMemoryTopic(
                    topicID: "startup-team",
                    title: "Team Preferences",
                    source: startupMemorySource,
                    availability: .present
                )
            ],
            onDemandMemoryTopics: [
                ResolvedInstructionMemoryTopic(
                    topicID: "release-process",
                    title: "Release Process",
                    source: onDemandMemorySource,
                    availability: .present
                )
            ],
            importEdges: [
                ResolvedInstructionImportEdge(
                    parentBlockID: userInstructionSource.sourcePath ?? "user",
                    childBlockID: importedInstructionSource.sourcePath ?? "imported",
                    rawToken: "@docs/guidelines.md",
                    tokenRange: nil,
                    resolvedPath: importedInstructionSource.sourcePath,
                    depth: 1,
                    isCycle: false
                )
            ],
            rootLoadOrder: [managedInstructionSource, userInstructionSource],
            notes: ["Preview fixture: Session instructions are projection-driven and read-only."]
        )

        let mcp = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "filesystem",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object([
                            "command": .string("npx"),
                            "args": .array([.string("-y"), .string("@modelcontextprotocol/server-filesystem"), .string("/Users/example/workspace")]),
                            "env": .object(["NODE_ENV": .string("${NODE_ENV}")])
                        ]),
                        winningSource: projectLocalSource,
                        trace: ResolutionTrace(
                            participants: [projectLocalSource, userSource],
                            overridden: [userSource],
                            notes: ["Project-local MCP definition overrides user scope definition by precedence."]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        notes: ["Selected highest-precedence usable MCP server definition."]
                    ),
                    environmentNotes: [
                        McpEnvironmentNote(
                            fieldPath: "env.NODE_ENV",
                            classification: .containsReference,
                            message: "MCP field 'env.NODE_ENV' contains an environment reference pattern."
                        )
                    ]
                )
            ],
            notes: ["Preview fixture: Session MCP view is projection-driven and read-only."]
        )

        let projectAgentSource = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-agent-reviewer",
            displayName: "project reviewer",
            sourcePath: "/Users/example/workspace/.claude/agents/reviewer.md"
        )
        let userAgentSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-agent-reviewer",
            displayName: "user reviewer",
            sourcePath: "/Users/example/.claude/agents/reviewer.md"
        )
        let invalidAgentSource = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-agent-broken",
            displayName: "broken agent",
            sourcePath: "/Users/example/workspace/.claude/agents/broken.md"
        )
        let unavailableAgentSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-agent-unavailable",
            displayName: "legacy agent",
            sourcePath: "/Users/example/.claude/agents/legacy.md",
            availability: .inaccessible
        )

        let duplicateAgentIssue = ResolutionIssue(
            code: .duplicateIdentifier,
            severity: .warning,
            message: "Agent identity 'reviewer' was overridden by a higher-precedence definition.",
            source: userAgentSource,
            keyPath: "reviewer",
            relatedSources: [projectAgentSource, userAgentSource]
        )
        let invalidAgentIssue = ResolutionIssue(
            code: .invalidSource,
            severity: .error,
            message: "Agent source is present but did not produce a parsed document.",
            source: invalidAgentSource,
            keyPath: "broken"
        )
        let unavailableAgentIssue = ResolutionIssue(
            code: .inaccessibleSource,
            severity: .error,
            message: "Agent source is inaccessible and could not be read.",
            source: unavailableAgentSource,
            keyPath: "legacy"
        )

        let reviewerAgentDocument = ParsedAgentDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/Users/example/workspace/.claude/agents/reviewer.md")),
            frontmatter: ParsedAgentFrontmatter(
                name: "Reviewer",
                description: "Review code and provide actionable feedback.",
                tools: [ParsedAgentToolEntry(rawValue: "Read"), ParsedAgentToolEntry(rawValue: "Edit")],
                unknownFields: [:]
            ),
            rawFrontmatter: nil,
            promptBody: "Review the project changes and summarize risks."
        )

        let agents = ResolvedAgentSnapshot(
            agents: [
                ResolvedAgentEntry(
                    agentID: "reviewer",
                    source: projectAgentSource,
                    definition: ResolvedValue(
                        effectiveValue: reviewerAgentDocument,
                        winningSource: projectAgentSource,
                        trace: ResolutionTrace(
                            participants: [projectAgentSource, userAgentSource],
                            overridden: [userAgentSource],
                            notes: ["Agent entry resolved as effective."]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .effective,
                        winningSource: projectAgentSource,
                        trace: ResolutionTrace(
                            participants: [projectAgentSource, userAgentSource],
                            overridden: [userAgentSource],
                            notes: ["Agent visibility computed with project-over-user precedence."]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: true,
                        winningSource: projectAgentSource,
                        trace: ResolutionTrace(
                            participants: [projectAgentSource, userAgentSource],
                            overridden: [userAgentSource]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedAgentEntry(
                    agentID: "reviewer",
                    source: userAgentSource,
                    definition: ResolvedValue(
                        effectiveValue: reviewerAgentDocument,
                        winningSource: userAgentSource,
                        trace: ResolutionTrace(
                            participants: [projectAgentSource, userAgentSource],
                            overridden: [userAgentSource],
                            notes: ["Agent entry resolved as overridden."]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [duplicateAgentIssue]
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .overridden,
                        winningSource: projectAgentSource,
                        trace: ResolutionTrace(
                            participants: [projectAgentSource, userAgentSource],
                            overridden: [userAgentSource],
                            notes: ["Agent visibility computed with project-over-user precedence."]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [duplicateAgentIssue]
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: false,
                        winningSource: projectAgentSource,
                        trace: ResolutionTrace(
                            participants: [projectAgentSource, userAgentSource],
                            overridden: [userAgentSource]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [duplicateAgentIssue]
                    )
                ),
                ResolvedAgentEntry(
                    agentID: "broken",
                    source: invalidAgentSource,
                    definition: ResolvedValue(
                        effectiveValue: nil,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [invalidAgentSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidAgentIssue]
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .invalid,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [invalidAgentSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidAgentIssue]
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: false,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [invalidAgentSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidAgentIssue]
                    )
                ),
                ResolvedAgentEntry(
                    agentID: "legacy",
                    source: unavailableAgentSource,
                    definition: ResolvedValue(
                        effectiveValue: nil,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [unavailableAgentSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [unavailableAgentIssue]
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .unavailable,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [unavailableAgentSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [unavailableAgentIssue]
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: false,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [unavailableAgentSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [unavailableAgentIssue]
                    )
                )
            ],
            issues: [duplicateAgentIssue, invalidAgentIssue, unavailableAgentIssue],
            notes: ["Preview fixture: Session agents view is projection-driven and read-only."]
        )

        let projectSkillSource = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-skill-release",
            displayName: "project release skill",
            sourcePath: "/Users/example/workspace/.claude/skills/release/SKILL.md"
        )
        let userSkillSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-skill-release",
            displayName: "user release skill",
            sourcePath: "/Users/example/.claude/skills/release/SKILL.md"
        )
        let invalidSkillSource = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-skill-broken",
            displayName: "broken skill",
            sourcePath: "/Users/example/workspace/.claude/skills/broken/SKILL.md"
        )
        let unavailableSkillSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-skill-unavailable",
            displayName: "legacy skill",
            sourcePath: "/Users/example/.claude/skills/legacy/SKILL.md",
            availability: .missing
        )

        let duplicateSkillIssue = ResolutionIssue(
            code: .duplicateIdentifier,
            severity: .warning,
            message: "Skill identity 'release' was overridden by a higher-precedence definition.",
            source: userSkillSource,
            keyPath: "release",
            relatedSources: [projectSkillSource, userSkillSource]
        )
        let invalidSkillIssue = ResolutionIssue(
            code: .unsupportedShape,
            severity: .error,
            message: "Skill directory is missing SKILL.md and remains discovered but unavailable for effective visibility.",
            source: invalidSkillSource,
            keyPath: "broken"
        )
        let unavailableSkillIssue = ResolutionIssue(
            code: .missingSource,
            severity: .warning,
            message: "Skill source is missing and was skipped.",
            source: unavailableSkillSource,
            keyPath: "legacy"
        )

        let releaseSkillDocument = ParsedSkillDocument(
            directory: SkillDirectoryMetadata(
                skillRootURL: URL(fileURLWithPath: "/Users/example/workspace/.claude/skills/release"),
                skillMarkdownURL: URL(fileURLWithPath: "/Users/example/workspace/.claude/skills/release/SKILL.md"),
                hasSkillMarkdown: true
            ),
            frontmatter: ParsedSkillFrontmatter(
                name: "Release",
                description: "Prepare release notes and launch checklist.",
                version: "1.0.0",
                tags: ["release", "ops"],
                unknownFields: [:]
            ),
            rawFrontmatter: nil,
            body: "Generate release notes and run launch checks.",
            supportingReferences: []
        )

        let skills = ResolvedSkillSnapshot(
            skills: [
                ResolvedSkillEntry(
                    skillID: "release",
                    source: projectSkillSource,
                    definition: ResolvedValue(
                        effectiveValue: releaseSkillDocument,
                        winningSource: projectSkillSource,
                        trace: ResolutionTrace(
                            participants: [projectSkillSource, userSkillSource],
                            overridden: [userSkillSource],
                            notes: ["Skill entry resolved as effective."]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .effective,
                        winningSource: projectSkillSource,
                        trace: ResolutionTrace(
                            participants: [projectSkillSource, userSkillSource],
                            overridden: [userSkillSource],
                            notes: ["Skill visibility computed with project-over-user precedence."]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: true,
                        winningSource: projectSkillSource,
                        trace: ResolutionTrace(
                            participants: [projectSkillSource, userSkillSource],
                            overridden: [userSkillSource]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedSkillEntry(
                    skillID: "release",
                    source: userSkillSource,
                    definition: ResolvedValue(
                        effectiveValue: releaseSkillDocument,
                        winningSource: userSkillSource,
                        trace: ResolutionTrace(
                            participants: [projectSkillSource, userSkillSource],
                            overridden: [userSkillSource],
                            notes: ["Skill entry resolved as overridden."]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [duplicateSkillIssue]
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .overridden,
                        winningSource: projectSkillSource,
                        trace: ResolutionTrace(
                            participants: [projectSkillSource, userSkillSource],
                            overridden: [userSkillSource],
                            notes: ["Skill visibility computed with project-over-user precedence."]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [duplicateSkillIssue]
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: false,
                        winningSource: projectSkillSource,
                        trace: ResolutionTrace(
                            participants: [projectSkillSource, userSkillSource],
                            overridden: [userSkillSource]
                        ),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [duplicateSkillIssue]
                    )
                ),
                ResolvedSkillEntry(
                    skillID: "broken",
                    source: invalidSkillSource,
                    definition: ResolvedValue(
                        effectiveValue: nil,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [invalidSkillSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidSkillIssue]
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .invalid,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [invalidSkillSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidSkillIssue]
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: false,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [invalidSkillSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidSkillIssue]
                    )
                ),
                ResolvedSkillEntry(
                    skillID: "legacy",
                    source: unavailableSkillSource,
                    definition: ResolvedValue(
                        effectiveValue: nil,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [unavailableSkillSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [unavailableSkillIssue]
                    ),
                    visibility: ResolvedValue(
                        effectiveValue: .unavailable,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [unavailableSkillSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [unavailableSkillIssue]
                    ),
                    isVisible: ResolvedValue(
                        effectiveValue: false,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [unavailableSkillSource]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [unavailableSkillIssue]
                    )
                )
            ],
            issues: [duplicateSkillIssue, invalidSkillIssue, unavailableSkillIssue],
            notes: ["Preview fixture: Session skills view is projection-driven and read-only."]
        )

        return SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(
                settings: settings,
                instructions: instructions,
                mcp: mcp,
                agents: agents,
                skills: skills,
                notes: ["Using local preview projection until resolver pipeline wiring packet."]
            )
        )
    }()
}

struct SessionSettingsView: View {
    let viewModel: SessionSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                summaryCard

                switch viewModel.state {
                case .missing:
                    missingStateCard
                case .empty:
                    emptyStateCard
                case .populated:
                    ForEach(viewModel.sections) { section in
                        sectionCard(section)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Session")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Settings", systemImage: "slider.horizontal.3")
                .font(.largeTitle.weight(.semibold))

            Text("Inspect effective settings, winning sources, merge behavior, and diagnostics from SessionProjection.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snapshot summary")
                    .font(.headline)
                Spacer()
                Text(viewModel.stateLabel)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.stateBadgeColor.opacity(0.18), in: Capsule())
            }

            Text("\(viewModel.rowCount) settings rows across \(viewModel.sections.count) sections")
                .font(.subheadline)

            Text("Issues: \(viewModel.errorCount) errors, \(viewModel.warningCount) warnings, \(viewModel.infoCount) info")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(viewModel.summaryNotes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    private var missingStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No settings projection available")
                .font(.headline)
            Text("Session settings are currently unavailable. The view stays read-only and displays completeness diagnostics.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No effective settings rows")
                .font(.headline)
            Text("The settings family is available but did not produce effective key rows.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionCard(_ section: SessionSettingsSectionModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.headline)
                Spacer()
                Text("\(section.rows.count) row\(section.rows.count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !section.issueBadges.isEmpty {
                issueBadgesView(section.issueBadges)
            }

            ForEach(section.rows) { row in
                rowCard(row)
            }

            ForEach(section.notes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func rowCard(_ row: ResolvedSettingRowModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(row.keyPath)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                Spacer()
                Text(row.mergeMethodLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Text(row.valueDisplay)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)

            if let winner = row.winningSourceChip {
                Text("Winning source: \(winner.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("Winning source: none")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !row.participantSourceChips.isEmpty {
                Text("Participants: \(row.participantSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.overriddenSourceChips.isEmpty {
                Text("Overridden: \(row.overriddenSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.issueBadges.isEmpty {
                issueBadgesView(row.issueBadges)
            }

            ForEach(row.notes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func issueBadgesView(_ badges: [IssueBadgeModel]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges) { badge in
                Text("\(badge.count) \(badge.label)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.18), in: Capsule())
            }
        }
    }
}

struct SessionInstructionsView: View {
    let viewModel: SessionInstructionsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                summaryCard

                switch viewModel.state {
                case .missing:
                    missingStateCard
                case .empty:
                    emptyStateCard
                case .populated:
                    if !viewModel.rootLoadOrder.isEmpty {
                        rootsCard
                    }

                    if !viewModel.entries.isEmpty {
                        entriesCard
                    }

                    if !viewModel.importRelations.isEmpty {
                        importsCard
                    }

                    if !viewModel.memorySections.isEmpty {
                        memoryCard
                    }

                    diagnosticsCard
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Instructions", systemImage: "text.append")
                .font(.largeTitle.weight(.semibold))

            Text("Inspect load order, import participation, startup memory, and on-demand memory from SessionProjection.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snapshot summary")
                    .font(.headline)
                Spacer()
                Text(viewModel.stateLabel)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.stateBadgeColor.opacity(0.18), in: Capsule())
            }

            Text("\(viewModel.entries.count) loaded instruction entries, \(viewModel.importRelations.count) import relations")
                .font(.subheadline)
            Text("Memory: \(viewModel.startupMemoryCount) startup, \(viewModel.onDemandMemoryCount) on-demand")
                .font(.subheadline)

            if viewModel.isPartial {
                Text("Partial resolution: some instruction branches resolved with diagnostics.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Text("Issues: \(viewModel.issueSummary.errorCount) errors, \(viewModel.issueSummary.warningCount) warnings, \(viewModel.issueSummary.infoCount) info")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(viewModel.summaryNotes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    private var missingStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No instructions projection available")
                .font(.headline)
            Text("Session instructions are currently unavailable. The view remains read-only and surfaces completeness diagnostics.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No resolved instruction entries")
                .font(.headline)
            Text("The instructions family is available but did not produce load-order rows, import edges, or memory entries.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var rootsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Root Load Order")
                .font(.headline)

            ForEach(Array(viewModel.rootLoadOrder.enumerated()), id: \.element.id) { pair in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(pair.offset + 1).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.element.title)
                            .font(.subheadline.weight(.semibold))
                        Text(pair.element.pathLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resolved Instruction Entries")
                .font(.headline)

            ForEach(viewModel.entries) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Depth \(row.depth)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }

                    Text(row.pathLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if let preview = row.contentPreview {
                        Text(preview)
                            .font(.footnote)
                            .lineLimit(3)
                            .foregroundStyle(.secondary)
                    }

                    if !row.importTargets.isEmpty {
                        Text("Imports: \(row.importTargets.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if !row.issueBadges.isEmpty {
                        issueBadgesView(row.issueBadges)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var importsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import Relationships")
                .font(.headline)

            ForEach(viewModel.importRelations) { relation in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(relation.parentTitle) -> \(relation.childTitle)")
                        .font(.subheadline.weight(.semibold))

                    Text("Token: \(relation.rawToken)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if let resolvedPath = relation.resolvedPath {
                        Text("Resolved path: \(resolvedPath)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 8) {
                        Text("Depth \(relation.depth)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        if relation.isCycle {
                            Text("Cycle")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.20), in: Capsule())
                        } else if relation.isResolved == false {
                            Text("Unresolved")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.25), in: Capsule())
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto Memory")
                .font(.headline)

            ForEach(viewModel.memorySections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(section.rows.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if section.rows.isEmpty {
                        Text("No entries")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(section.rows) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.footnote.weight(.semibold))
                                Text(row.pathLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text("Availability: \(row.availabilityLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnostics")
                .font(.headline)

            issueBadgesView(viewModel.issueSummary.badges)

            if viewModel.issueSummary.cycleCount > 0 {
                Text("Cycle diagnostics: \(viewModel.issueSummary.cycleCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if viewModel.issueSummary.unresolvedImportCount > 0 {
                Text("Unresolved imports: \(viewModel.issueSummary.unresolvedImportCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if viewModel.issueSummary.depthLimitCount > 0 {
                Text("Depth-limit issues: \(viewModel.issueSummary.depthLimitCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.issueSummary.messagePreview, id: \.self) { message in
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func issueBadgesView(_ badges: [IssueBadgeModel]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges) { badge in
                Text("\(badge.count) \(badge.label)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.18), in: Capsule())
            }
        }
    }
}

struct SessionHooksView: View {
    let viewModel: SessionHooksViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                summaryCard

                if !viewModel.restrictionBadges.isEmpty {
                    restrictionsCard
                }

                switch viewModel.state {
                case .missing:
                    missingStateCard
                case .empty:
                    emptyStateCard
                case .populated:
                    ForEach(viewModel.groups) { group in
                        groupCard(group)
                    }
                    diagnosticsCard
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Hooks", systemImage: "point.3.filled.connected.trianglepath.dotted")
                .font(.largeTitle.weight(.semibold))

            Text("Inspect effective hooks grouped by event and matcher context, with provenance, restrictions, and diagnostics.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snapshot summary")
                    .font(.headline)
                Spacer()
                Text(viewModel.stateLabel)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.stateBadgeColor.opacity(0.18), in: Capsule())
            }

            Text("\(viewModel.groupCount) groups, \(viewModel.rowCount) effective actions")
                .font(.subheadline)

            Text("Issues: \(viewModel.errorCount) errors, \(viewModel.warningCount) warnings, \(viewModel.infoCount) info")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(viewModel.summaryNotes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    private var restrictionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Restrictions")
                .font(.headline)

            ForEach(viewModel.restrictionBadges) { badge in
                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.title)
                        .font(.subheadline.weight(.semibold))
                    Text(badge.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(badge.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var missingStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No hooks projection available")
                .font(.headline)
            Text("Session hooks are currently unavailable. The screen remains read-only and surfaces projection completeness notes.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No effective hooks")
                .font(.headline)
            Text("The hooks family is available but did not produce event groups with effective actions.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func groupCard(_ group: HookGroupModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.eventTitle)
                        .font(.headline)
                    Text("Matcher: \(group.matcherLabel)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(group.rows.count) action\(group.rows.count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !group.issueBadges.isEmpty {
                issueBadgesView(group.issueBadges)
            }

            if !group.capabilityBadges.isEmpty {
                capabilityBadgesView(group.capabilityBadges)
            }

            if let capabilityNote = group.capabilityNote {
                Text(capabilityNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(group.rows) { row in
                rowCard(row)
            }

            ForEach(group.notes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func rowCard(_ row: HookRowModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(row.actionSummary)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("#\(row.displayIndex)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Text(row.rawPayloadSummary)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)

            if let winner = row.winningSourceChip {
                Text("Winning source: \(winner.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("Winning source: none")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !row.participantSourceChips.isEmpty {
                Text("Participants: \(row.participantSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.overriddenSourceChips.isEmpty {
                Text("Overridden: \(row.overriddenSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.issueBadges.isEmpty {
                issueBadgesView(row.issueBadges)
            }

            ForEach(row.notes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnostics")
                .font(.headline)

            issueBadgesView(viewModel.issueBadges)

            if viewModel.issues.isEmpty {
                Text("No hook diagnostics were reported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.issues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.message)
                            .font(.footnote.weight(.semibold))
                        if let path = issue.keyPath {
                            Text("Key: \(path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let source = issue.sourceLabel {
                            Text("Source: \(source)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(issue.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func issueBadgesView(_ badges: [IssueBadgeModel]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges) { badge in
                Text("\(badge.count) \(badge.label)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.18), in: Capsule())
            }
        }
    }

    private func capabilityBadgesView(_ badges: [HookCapabilityBadgeModel]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges) { badge in
                Text(badge.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.18), in: Capsule())
            }
        }
    }
}

struct SessionMCPView: View {
    let viewModel: SessionMCPViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                summaryCard

                switch viewModel.state {
                case .missing:
                    missingStateCard
                case .empty:
                    emptyStateCard
                case .populated:
                    serversCard
                    if !viewModel.overriddenServers.isEmpty {
                        overridesCard
                    }
                    diagnosticsCard
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session MCP", systemImage: "server.rack")
                .font(.largeTitle.weight(.semibold))

            Text("Inspect effective MCP server definitions, override provenance, and diagnostics from SessionProjection.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snapshot summary")
                    .font(.headline)
                Spacer()
                Text(viewModel.stateLabel)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.stateBadgeColor.opacity(0.18), in: Capsule())
            }

            Text("\(viewModel.serverRows.count) effective server\(viewModel.serverRows.count == 1 ? "" : "s"), \(viewModel.overriddenServers.count) with overrides")
                .font(.subheadline)
            Text("Issues: \(viewModel.errorCount) errors, \(viewModel.warningCount) warnings, \(viewModel.infoCount) info")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.isPartial {
                Text("Partial MCP projection: one or more servers have incomplete winning-source or config details.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            ForEach(viewModel.summaryNotes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    private var missingStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No MCP projection available")
                .font(.headline)
            Text("Session MCP is currently unavailable. The screen remains read-only and surfaces completeness diagnostics.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No effective MCP servers")
                .font(.headline)
            Text("The MCP family is available but did not produce effective server definitions.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var serversCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Effective Servers")
                .font(.headline)

            ForEach(viewModel.serverRows) { row in
                serverRowCard(row)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func serverRowCard(_ row: McpServerRowModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(row.serverID)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                Spacer()
                Text(row.mergeMethodLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Text(row.configSummary)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)

            if let winner = row.winningSourceChip {
                Text("Winning source: \(winner.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("Winning source: none")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !row.participantSourceChips.isEmpty {
                Text("Participants: \(row.participantSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.overriddenSourceChips.isEmpty {
                Text("Overridden: \(row.overriddenSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.issueBadges.isEmpty {
                issueBadgesView(row.issueBadges)
            }

            if !row.environmentNotes.isEmpty {
                HStack(spacing: 8) {
                    Text("\(row.environmentNotes.count) env note\(row.environmentNotes.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.18), in: Capsule())
                }
                ForEach(row.environmentNotes, id: \.id) { note in
                    Text(note.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(row.notes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var overridesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overridden Definitions")
                .font(.headline)

            ForEach(viewModel.overriddenServers) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.serverID)
                        .font(.subheadline.weight(.semibold))
                    if let winner = item.winningSourceLabel {
                        Text("Effective source: \(winner)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Text("Overridden sources: \(item.overriddenSourceLabels.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(item.reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnostics")
                .font(.headline)

            issueBadgesView(viewModel.issueBadges)

            HStack(spacing: 8) {
                Text("\(viewModel.conflictCount) conflicts")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.18), in: Capsule())
                Text("\(viewModel.invalidDefinitionCount) invalid definitions")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.18), in: Capsule())
                Text("\(viewModel.environmentNoteCount) env notes")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.18), in: Capsule())
            }

            if viewModel.diagnostics.isEmpty {
                Text("No MCP diagnostics were reported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.diagnostics) { diagnostic in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diagnostic.message)
                            .font(.footnote.weight(.semibold))
                        if let serverID = diagnostic.serverID {
                            Text("Server: \(serverID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let source = diagnostic.sourceLabel {
                            Text("Source: \(source)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(diagnostic.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func issueBadgesView(_ badges: [IssueBadgeModel]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges) { badge in
                Text("\(badge.count) \(badge.label)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.18), in: Capsule())
            }
        }
    }
}

struct SessionAgentsSkillsView: View {
    private enum VisibleSection: String, CaseIterable, Identifiable {
        case agents
        case skills

        var id: String { rawValue }

        var title: String {
            switch self {
            case .agents:
                return "Agents"
            case .skills:
                return "Skills"
            }
        }
    }

    let viewModel: SessionAgentsSkillsViewModel
    @State private var visibleSection: VisibleSection = .agents

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                summaryCard

                switch viewModel.state {
                case .missing:
                    missingStateCard
                case .empty:
                    emptyStateCard
                case .populated:
                    Picker("Visibility Surface", selection: $visibleSection) {
                        ForEach(VisibleSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    if visibleSection == .agents {
                        entriesCard(title: "Agent Visibility", count: viewModel.agentRows.count) {
                            ForEach(viewModel.agentRows) { row in
                                agentRowCard(row)
                            }
                        }
                    } else {
                        entriesCard(title: "Skill Visibility", count: viewModel.skillRows.count) {
                            ForEach(viewModel.skillRows) { row in
                                skillRowCard(row)
                            }
                        }
                    }

                    if !viewModel.overrides.isEmpty {
                        overridesCard
                    }
                    diagnosticsCard
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Agents & Skills", systemImage: "person.2.badge.gearshape")
                .font(.largeTitle.weight(.semibold))

            Text("Inspect effective visibility, overrides, and diagnostics for agent and skill definitions from SessionProjection.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snapshot summary")
                    .font(.headline)
                Spacer()
                Text(viewModel.stateLabel)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.stateBadgeColor.opacity(0.18), in: Capsule())
            }

            Text("\(viewModel.agentRows.count) agent row\(viewModel.agentRows.count == 1 ? "" : "s"), \(viewModel.skillRows.count) skill row\(viewModel.skillRows.count == 1 ? "" : "s")")
                .font(.subheadline)
            Text("Visibility: \(viewModel.effectiveCount) effective, \(viewModel.overriddenCount) overridden, \(viewModel.invalidCount) invalid, \(viewModel.unavailableCount) unavailable")
                .font(.subheadline)
            Text("Issues: \(viewModel.errorCount) errors, \(viewModel.warningCount) warnings, \(viewModel.infoCount) info")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(viewModel.summaryNotes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    private var missingStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No agents/skills projection available")
                .font(.headline)
            Text("Session agents and skills are currently unavailable. This screen remains read-only and surfaces completeness diagnostics.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No visible agent or skill entries")
                .font(.headline)
            Text("The agents/skills family is available but did not produce any resolved rows.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func entriesCard<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count) row\(count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func agentRowCard(_ row: AgentVisibilityRowModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(row.agentID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.visibilityLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(row.visibilityColor.opacity(0.18), in: Capsule())
            }

            Text("Source: \(row.sourceChip.label)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let description = row.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let toolsSummary = row.toolsSummary {
                Text("Tools: \(toolsSummary)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let winner = row.winningSourceChip {
                Text("Winning replacement: \(winner.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.participantSourceChips.isEmpty {
                Text("Participants: \(row.participantSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !row.overriddenSourceChips.isEmpty {
                Text("Overridden: \(row.overriddenSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.issueBadges.isEmpty {
                issueBadgesView(row.issueBadges)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func skillRowCard(_ row: SkillVisibilityRowModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(row.skillID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.visibilityLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(row.visibilityColor.opacity(0.18), in: Capsule())
            }

            Text("Source: \(row.sourceChip.label)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let description = row.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let version = row.version {
                Text("Version: \(version)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !row.tags.isEmpty {
                Text("Tags: \(row.tags.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let winner = row.winningSourceChip {
                Text("Winning replacement: \(winner.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.participantSourceChips.isEmpty {
                Text("Participants: \(row.participantSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !row.overriddenSourceChips.isEmpty {
                Text("Overridden: \(row.overriddenSourceChips.map(\.label).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !row.issueBadges.isEmpty {
                issueBadgesView(row.issueBadges)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var overridesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overridden Entries")
                .font(.headline)

            ForEach(viewModel.overrides) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.kindLabel): \(item.identity)")
                        .font(.subheadline.weight(.semibold))
                    Text("Overridden source: \(item.sourceLabel)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if let winner = item.winningReplacementLabel {
                        Text("Winning replacement: \(winner)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Text(item.reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnostics")
                .font(.headline)

            issueBadgesView(viewModel.issueBadges)

            if viewModel.diagnostics.isEmpty {
                Text("No agent/skill diagnostics were reported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.diagnostics) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.message)
                            .font(.footnote.weight(.semibold))
                        if let kindLabel = issue.kindLabel {
                            Text("Family: \(kindLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let keyPath = issue.keyPath {
                            Text("Identity: \(keyPath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let sourceLabel = issue.sourceLabel {
                            Text("Source: \(sourceLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if !issue.relatedSourceLabels.isEmpty {
                            Text("Related sources: \(issue.relatedSourceLabels.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(issue.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }

    private func issueBadgesView(_ badges: [IssueBadgeModel]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges) { badge in
                Text("\(badge.count) \(badge.label)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.color.opacity(0.18), in: Capsule())
            }
        }
    }
}

struct SessionAgentsSkillsViewModel: Equatable {
    enum State: Equatable {
        case missing
        case empty
        case populated
    }

    let state: State
    let agentRows: [AgentVisibilityRowModel]
    let skillRows: [SkillVisibilityRowModel]
    let overrides: [OverrideSummaryModel]
    let diagnostics: [AgentSkillIssueModel]
    let issueBadges: [IssueBadgeModel]
    let summaryNotes: [String]
    let effectiveCount: Int
    let overriddenCount: Int
    let invalidCount: Int
    let unavailableCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let isPartial: Bool

    init(projection: SessionProjection) {
        let agentFamilyState = projection.familyStates.first(where: { $0.family == .agents })
        let skillFamilyState = projection.familyStates.first(where: { $0.family == .skills })

        guard projection.agents != nil || projection.skills != nil else {
            state = .missing
            agentRows = []
            skillRows = []
            overrides = []
            diagnostics = []
            issueBadges = []
            summaryNotes = SessionSettingsViewModel.deduplicated(
                projection.completeness.confidenceNotes + projection.notes
            )
            effectiveCount = 0
            overriddenCount = 0
            invalidCount = 0
            unavailableCount = 0
            errorCount = 0
            warningCount = 0
            infoCount = 0
            isPartial = false
            return
        }

        let agents = projection.agents?.agents ?? []
        let skills = projection.skills?.skills ?? []
        agentRows = agents.map(AgentVisibilityRowModel.init).sorted(by: AgentVisibilityRowModel.sort)
        skillRows = skills.map(SkillVisibilityRowModel.init).sorted(by: SkillVisibilityRowModel.sort)

        let visibilityStates = agentRows.map(\.visibility) + skillRows.map(\.visibility)
        effectiveCount = visibilityStates.filter { $0 == .effective }.count
        overriddenCount = visibilityStates.filter { $0 == .overridden }.count
        invalidCount = visibilityStates.filter { $0 == .invalid }.count
        unavailableCount = visibilityStates.filter { $0 == .unavailable }.count

        overrides = SessionAgentsSkillsViewModel.buildOverrides(agentRows: agentRows, skillRows: skillRows)

        let allIssues = SessionAgentsSkillsViewModel.deduplicatedIssues(
            (projection.agents?.issues ?? []) +
                (projection.skills?.issues ?? []) +
                agentRows.flatMap(\.issues) +
                skillRows.flatMap(\.issues)
        )
        diagnostics = allIssues.map(AgentSkillIssueModel.init).sorted(by: AgentSkillIssueModel.sort)
        issueBadges = IssueBadgeModel.badges(for: allIssues)
        errorCount = allIssues.filter { $0.severity == .error }.count
        warningCount = allIssues.filter { $0.severity == .warning }.count
        infoCount = allIssues.filter { $0.severity == .info }.count

        state = (agentRows.isEmpty && skillRows.isEmpty) ? .empty : .populated

        let familyPartial = (agentFamilyState?.completeness == .partial) || (skillFamilyState?.completeness == .partial)
        let missingOneFamily = (projection.agents == nil) != (projection.skills == nil)
        isPartial = familyPartial || missingOneFamily || invalidCount > 0 || unavailableCount > 0

        let familyNotes = (projection.agents?.notes ?? []) + (projection.skills?.notes ?? [])
        let completenessNotes = projection.completeness.confidenceNotes.filter {
            $0.localizedCaseInsensitiveContains("agents") ||
                $0.localizedCaseInsensitiveContains("skills") ||
                $0.localizedCaseInsensitiveContains("families") ||
                $0.localizedCaseInsensitiveContains("partial")
        }
        let partialNotes = missingOneFamily
            ? ["Only one of agents/skills families is currently available, so this screen is in a partial state."]
            : []
        summaryNotes = SessionSettingsViewModel.deduplicated(
            familyNotes + (agentFamilyState?.confidenceNotes ?? []) + (skillFamilyState?.confidenceNotes ?? []) + completenessNotes + partialNotes
        )
    }

    var stateLabel: String {
        switch state {
        case .missing:
            return "Missing"
        case .empty:
            return "Empty"
        case .populated:
            return isPartial ? "Partial" : "Populated"
        }
    }

    var stateBadgeColor: Color {
        switch state {
        case .missing:
            return .orange
        case .empty:
            return .blue
        case .populated:
            return isPartial ? .orange : .green
        }
    }

    private static func buildOverrides(
        agentRows: [AgentVisibilityRowModel],
        skillRows: [SkillVisibilityRowModel]
    ) -> [OverrideSummaryModel] {
        let agentOverrides = agentRows
            .filter { $0.visibility == .overridden }
            .map {
                OverrideSummaryModel(
                    kindLabel: "Agent",
                    identity: $0.agentID,
                    sourceLabel: $0.sourceChip.label,
                    winningReplacementLabel: $0.winningSourceChip?.label,
                    reason: $0.overrideReason
                )
            }
        let skillOverrides = skillRows
            .filter { $0.visibility == .overridden }
            .map {
                OverrideSummaryModel(
                    kindLabel: "Skill",
                    identity: $0.skillID,
                    sourceLabel: $0.sourceChip.label,
                    winningReplacementLabel: $0.winningSourceChip?.label,
                    reason: $0.overrideReason
                )
            }

        return (agentOverrides + skillOverrides).sorted { lhs, rhs in
            if lhs.kindLabel != rhs.kindLabel {
                return lhs.kindLabel < rhs.kindLabel
            }
            if lhs.identity != rhs.identity {
                return lhs.identity < rhs.identity
            }
            return lhs.sourceLabel < rhs.sourceLabel
        }
    }

    static func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct AgentVisibilityRowModel: Identifiable, Equatable {
    let id: String
    let agentID: String
    let displayName: String
    let description: String?
    let toolsSummary: String?
    let sourceChip: SourceChipModel
    let visibility: VisibilityState
    let winningSourceChip: SourceChipModel?
    let participantSourceChips: [SourceChipModel]
    let overriddenSourceChips: [SourceChipModel]
    let issues: [ResolutionIssue]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    var visibilityLabel: String {
        switch visibility {
        case .effective:
            return "Effective"
        case .overridden:
            return "Overridden"
        case .invalid:
            return "Invalid"
        case .unavailable:
            return "Unavailable"
        }
    }

    var visibilityColor: Color {
        switch visibility {
        case .effective:
            return .green
        case .overridden:
            return .yellow
        case .invalid:
            return .red
        case .unavailable:
            return .orange
        }
    }

    var overrideReason: String {
        if let issue = issues.first(where: { $0.code == .duplicateIdentifier }) {
            return issue.message
        }
        if let note = notes.first(where: { $0.localizedCaseInsensitiveContains("override") }) {
            return note
        }
        return "Higher-precedence definition was selected."
    }

    init(entry: ResolvedAgentEntry) {
        id = "\(entry.agentID)-\(entry.source.id)"
        agentID = entry.agentID
        displayName = entry.definition.effectiveValue?.frontmatter?.name ?? entry.agentID
        description = entry.definition.effectiveValue?.frontmatter?.description
        let tools = entry.definition.effectiveValue?.frontmatter?.tools.map(\.rawValue) ?? []
        toolsSummary = tools.isEmpty ? nil : tools.joined(separator: ", ")
        sourceChip = SourceChipModel(source: entry.source)
        visibility = entry.visibility.effectiveValue ?? .invalid
        winningSourceChip = entry.visibility.winningSource.map(SourceChipModel.init)
        participantSourceChips = entry.visibility.trace.participants.map(SourceChipModel.init)
        overriddenSourceChips = entry.visibility.trace.overridden.map(SourceChipModel.init)
        issues = SessionAgentsSkillsViewModel.deduplicatedIssues(
            entry.definition.issues + entry.visibility.issues + entry.isVisible.issues
        )
        issueBadges = IssueBadgeModel.badges(for: issues)
        notes = SessionSettingsViewModel.deduplicated(
            entry.definition.notes +
                entry.visibility.notes +
                entry.isVisible.notes +
                entry.definition.trace.notes +
                entry.visibility.trace.notes
        )
    }

    static func sort(lhs: AgentVisibilityRowModel, rhs: AgentVisibilityRowModel) -> Bool {
        if lhs.visibility.sortRank != rhs.visibility.sortRank {
            return lhs.visibility.sortRank < rhs.visibility.sortRank
        }
        if lhs.agentID != rhs.agentID {
            return lhs.agentID < rhs.agentID
        }
        return lhs.sourceChip.label < rhs.sourceChip.label
    }
}

struct SkillVisibilityRowModel: Identifiable, Equatable {
    let id: String
    let skillID: String
    let displayName: String
    let description: String?
    let version: String?
    let tags: [String]
    let sourceChip: SourceChipModel
    let visibility: VisibilityState
    let winningSourceChip: SourceChipModel?
    let participantSourceChips: [SourceChipModel]
    let overriddenSourceChips: [SourceChipModel]
    let issues: [ResolutionIssue]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    var visibilityLabel: String {
        switch visibility {
        case .effective:
            return "Effective"
        case .overridden:
            return "Overridden"
        case .invalid:
            return "Invalid"
        case .unavailable:
            return "Unavailable"
        }
    }

    var visibilityColor: Color {
        switch visibility {
        case .effective:
            return .green
        case .overridden:
            return .yellow
        case .invalid:
            return .red
        case .unavailable:
            return .orange
        }
    }

    var overrideReason: String {
        if let issue = issues.first(where: { $0.code == .duplicateIdentifier }) {
            return issue.message
        }
        if let note = notes.first(where: { $0.localizedCaseInsensitiveContains("override") }) {
            return note
        }
        return "Higher-precedence definition was selected."
    }

    init(entry: ResolvedSkillEntry) {
        id = "\(entry.skillID)-\(entry.source.id)"
        skillID = entry.skillID
        displayName = entry.definition.effectiveValue?.frontmatter?.name ?? entry.skillID
        description = entry.definition.effectiveValue?.frontmatter?.description
        version = entry.definition.effectiveValue?.frontmatter?.version
        tags = entry.definition.effectiveValue?.frontmatter?.tags?.sorted() ?? []
        sourceChip = SourceChipModel(source: entry.source)
        visibility = entry.visibility.effectiveValue ?? .invalid
        winningSourceChip = entry.visibility.winningSource.map(SourceChipModel.init)
        participantSourceChips = entry.visibility.trace.participants.map(SourceChipModel.init)
        overriddenSourceChips = entry.visibility.trace.overridden.map(SourceChipModel.init)
        issues = SessionAgentsSkillsViewModel.deduplicatedIssues(
            entry.definition.issues + entry.visibility.issues + entry.isVisible.issues
        )
        issueBadges = IssueBadgeModel.badges(for: issues)
        notes = SessionSettingsViewModel.deduplicated(
            entry.definition.notes +
                entry.visibility.notes +
                entry.isVisible.notes +
                entry.definition.trace.notes +
                entry.visibility.trace.notes
        )
    }

    static func sort(lhs: SkillVisibilityRowModel, rhs: SkillVisibilityRowModel) -> Bool {
        if lhs.visibility.sortRank != rhs.visibility.sortRank {
            return lhs.visibility.sortRank < rhs.visibility.sortRank
        }
        if lhs.skillID != rhs.skillID {
            return lhs.skillID < rhs.skillID
        }
        return lhs.sourceChip.label < rhs.sourceChip.label
    }
}

struct OverrideSummaryModel: Identifiable, Equatable {
    let kindLabel: String
    let identity: String
    let sourceLabel: String
    let winningReplacementLabel: String?
    let reason: String

    var id: String { "\(kindLabel)-\(identity)-\(sourceLabel)" }
}

struct AgentSkillIssueModel: Identifiable, Equatable {
    let id: String
    let severity: ResolutionIssueSeverity
    let message: String
    let kindLabel: String?
    let keyPath: String?
    let sourceLabel: String?
    let relatedSourceLabels: [String]

    var color: Color {
        switch severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    init(issue: ResolutionIssue) {
        id = issue.id
        severity = issue.severity
        message = issue.message
        keyPath = issue.keyPath
        sourceLabel = issue.source?.sourcePath ?? issue.source?.displayName ?? issue.source?.identifier
        relatedSourceLabels = issue.relatedSources
            .map { $0.sourcePath ?? $0.displayName ?? $0.identifier }
            .sorted()

        if issue.message.localizedCaseInsensitiveContains("skill") {
            kindLabel = "Skills"
        } else if issue.message.localizedCaseInsensitiveContains("agent") {
            kindLabel = "Agents"
        } else if let keyPath = issue.keyPath, keyPath.localizedCaseInsensitiveContains("skill") {
            kindLabel = "Skills"
        } else if let keyPath = issue.keyPath, keyPath.localizedCaseInsensitiveContains("agent") {
            kindLabel = "Agents"
        } else {
            kindLabel = nil
        }
    }

    static func sort(lhs: AgentSkillIssueModel, rhs: AgentSkillIssueModel) -> Bool {
        if lhs.severity != rhs.severity {
            return severityRank(lhs.severity) > severityRank(rhs.severity)
        }
        if lhs.kindLabel != rhs.kindLabel {
            return (lhs.kindLabel ?? "") < (rhs.kindLabel ?? "")
        }
        if lhs.keyPath != rhs.keyPath {
            return (lhs.keyPath ?? "") < (rhs.keyPath ?? "")
        }
        return lhs.message < rhs.message
    }

    private static func severityRank(_ severity: ResolutionIssueSeverity) -> Int {
        switch severity {
        case .error:
            return 3
        case .warning:
            return 2
        case .info:
            return 1
        }
    }
}

struct SessionMCPViewModel: Equatable {
    enum State: Equatable {
        case missing
        case empty
        case populated
    }

    let state: State
    let serverRows: [McpServerRowModel]
    let overriddenServers: [OverriddenServerModel]
    let diagnostics: [McpDiagnosticModel]
    let issueBadges: [IssueBadgeModel]
    let summaryNotes: [String]
    let conflictCount: Int
    let invalidDefinitionCount: Int
    let environmentNoteCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let isPartial: Bool

    init(projection: SessionProjection) {
        let familyState = projection.familyStates.first(where: { $0.family == .mcp })
        guard let mcp = projection.mcp else {
            state = .missing
            serverRows = []
            overriddenServers = []
            diagnostics = []
            issueBadges = []
            summaryNotes = SessionSettingsViewModel.deduplicated(
                projection.completeness.confidenceNotes + projection.notes
            )
            conflictCount = 0
            invalidDefinitionCount = 0
            environmentNoteCount = 0
            errorCount = 0
            warningCount = 0
            infoCount = 0
            isPartial = false
            return
        }

        let rows = mcp.servers.map(McpServerRowModel.init).sorted { $0.serverID < $1.serverID }
        serverRows = rows

        overriddenServers = rows
            .filter { $0.overriddenSourceChips.isEmpty == false }
            .map {
                OverriddenServerModel(
                    serverID: $0.serverID,
                    winningSourceLabel: $0.winningSourceChip?.label,
                    overriddenSourceLabels: $0.overriddenSourceChips.map(\.label),
                    reason: $0.overrideReason
                )
            }

        let nestedIssues = rows.flatMap(\.issues)
        let allIssues = SessionMCPViewModel.deduplicatedIssues(mcp.issues + nestedIssues)
        diagnostics = SessionMCPViewModel.buildDiagnostics(rows: rows, issues: allIssues)
        issueBadges = IssueBadgeModel.badges(for: allIssues)
        errorCount = allIssues.filter { $0.severity == .error }.count
        warningCount = allIssues.filter { $0.severity == .warning }.count
        infoCount = allIssues.filter { $0.severity == .info }.count

        conflictCount = allIssues.filter { issue in
            issue.code == .conflict || issue.code == .duplicateIdentifier
        }.count
        invalidDefinitionCount = allIssues.filter { issue in
            SessionMCPViewModel.invalidIssueCodes.contains(issue.code)
        }.count
        environmentNoteCount = rows.reduce(into: 0) { partialResult, row in
            partialResult += row.environmentNotes.count
        }

        let rowPartial = rows.contains { $0.winningSourceChip == nil || $0.configSummary == "(unresolved)" }
        isPartial = (familyState?.completeness == .partial) || rowPartial

        state = rows.isEmpty ? .empty : .populated

        let mcpCompletenessNotes = projection.completeness.confidenceNotes.filter {
            $0.localizedCaseInsensitiveContains("mcp") ||
                $0.localizedCaseInsensitiveContains("families") ||
                $0.localizedCaseInsensitiveContains("partial")
        }
        let provenanceNote = rowPartial
            ? ["Some MCP rows are shown with partial provenance because winning source or config data is unresolved."]
            : []
        summaryNotes = SessionSettingsViewModel.deduplicated(
            mcp.notes + (familyState?.confidenceNotes ?? []) + mcpCompletenessNotes + provenanceNote
        )
    }

    var stateLabel: String {
        switch state {
        case .missing:
            return "Missing"
        case .empty:
            return "Empty"
        case .populated:
            return isPartial ? "Partial" : "Populated"
        }
    }

    var stateBadgeColor: Color {
        switch state {
        case .missing:
            return .orange
        case .empty:
            return .blue
        case .populated:
            return isPartial ? .orange : .green
        }
    }

    private static let invalidIssueCodes: Set<ResolutionIssueCode> = [
        .invalidSource,
        .inaccessibleSource,
        .missingSource,
        .unsupportedShape,
        .typeMismatch,
        .unresolvedValue,
        .parserSyntaxIssue
    ]

    private static func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }

    private static func buildDiagnostics(rows: [McpServerRowModel], issues: [ResolutionIssue]) -> [McpDiagnosticModel] {
        var models = issues.map { issue in
            McpDiagnosticModel(
                message: issue.message,
                serverID: issue.keyPath.map { SessionMCPViewModel.serverIDFromKeyPath($0) },
                sourceLabel: issue.source?.sourcePath ?? issue.source?.displayName ?? issue.source?.identifier,
                tone: McpDiagnosticModel.tone(for: issue.severity)
            )
        }

        let noteModels = rows.flatMap { row in
            row.environmentNotes.map { note in
                McpDiagnosticModel(
                    message: note.message,
                    serverID: row.serverID,
                    sourceLabel: row.winningSourceChip?.label,
                    tone: .info
                )
            }
        }
        models.append(contentsOf: noteModels)

        return models.sorted { lhs, rhs in
            if lhs.serverID != rhs.serverID {
                return (lhs.serverID ?? "") < (rhs.serverID ?? "")
            }
            return lhs.message < rhs.message
        }
    }

    private static func serverIDFromKeyPath(_ keyPath: String) -> String {
        guard keyPath.hasPrefix("mcpServers.") else { return keyPath }
        return String(keyPath.dropFirst("mcpServers.".count).split(separator: ".").first ?? "")
    }
}

struct McpServerRowModel: Identifiable, Equatable {
    let serverID: String
    let configSummary: String
    let mergeMethod: MergeMethod
    let winningSourceChip: SourceChipModel?
    let participantSourceChips: [SourceChipModel]
    let overriddenSourceChips: [SourceChipModel]
    let issues: [ResolutionIssue]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]
    let environmentNotes: [McpEnvironmentRowNote]

    var id: String { serverID }

    var mergeMethodLabel: String {
        switch mergeMethod {
        case .selectHighestPrecedence:
            return "Select Highest"
        case .replace:
            return "Replace"
        case .deepMergeObject:
            return "Deep Merge"
        case .append:
            return "Append"
        case .appendUnique:
            return "Append Unique"
        case .setUnion:
            return "Set Union"
        case .keyedByIdentifier:
            return "Keyed Merge"
        case .passthrough:
            return "Passthrough"
        }
    }

    var overrideReason: String {
        if let note = notes.first(where: { note in
            note.localizedCaseInsensitiveContains("override") ||
                note.localizedCaseInsensitiveContains("precedence") ||
                note.localizedCaseInsensitiveContains("fallback")
        }) {
            return note
        }
        return "Higher-precedence usable definition was selected."
    }

    init(entry: ResolvedMcpServerEntry) {
        serverID = entry.serverID
        configSummary = McpServerRowModel.formatJSON(entry.resolvedConfig.effectiveValue)
        mergeMethod = entry.resolvedConfig.mergeMethod
        winningSourceChip = entry.resolvedConfig.winningSource.map(SourceChipModel.init)
        participantSourceChips = entry.resolvedConfig.trace.participants.map(SourceChipModel.init)
        overriddenSourceChips = entry.resolvedConfig.trace.overridden.map(SourceChipModel.init)
        issues = entry.resolvedConfig.issues
        issueBadges = IssueBadgeModel.badges(for: entry.resolvedConfig.issues)
        notes = SessionSettingsViewModel.deduplicated(entry.resolvedConfig.notes + entry.resolvedConfig.trace.notes)
        environmentNotes = entry.environmentNotes.map(McpEnvironmentRowNote.init)
    }

    private static func formatJSON(_ value: JSONValue?) -> String {
        guard let value else {
            return "(unresolved)"
        }

        switch value {
        case let .string(string):
            return "\"\(string)\""
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        case let .array(array):
            if array.isEmpty {
                return "[]"
            }
            return "[\(array.map { formatJSON($0) }.joined(separator: ", "))]"
        case let .object(object):
            if object.isEmpty {
                return "{}"
            }
            let pairs = object.keys.sorted().map { key in
                "\(key): \(formatJSON(object[key]))"
            }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

struct OverriddenServerModel: Identifiable, Equatable {
    let serverID: String
    let winningSourceLabel: String?
    let overriddenSourceLabels: [String]
    let reason: String

    var id: String { serverID }
}

struct McpEnvironmentRowNote: Identifiable, Equatable {
    let fieldPath: String
    let classification: McpEnvironmentClassification
    let message: String

    var id: String { "\(fieldPath)-\(classification.rawValue)-\(message)" }

    init(note: McpEnvironmentNote) {
        fieldPath = note.fieldPath
        classification = note.classification
        message = note.message
    }
}

struct McpDiagnosticModel: Identifiable, Equatable {
    enum Tone: Equatable {
        case error
        case warning
        case info
    }

    let id: String
    let message: String
    let serverID: String?
    let sourceLabel: String?
    let tone: Tone

    var color: Color {
        switch tone {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    init(message: String, serverID: String?, sourceLabel: String?, tone: Tone) {
        self.message = message
        self.serverID = serverID
        self.sourceLabel = sourceLabel
        self.tone = tone
        self.id = "\(serverID ?? "none")-\(sourceLabel ?? "none")-\(message)"
    }

    static func tone(for severity: ResolutionIssueSeverity) -> Tone {
        switch severity {
        case .error:
            return .error
        case .warning:
            return .warning
        case .info:
            return .info
        }
    }
}

struct SessionHooksViewModel: Equatable {
    enum State: Equatable {
        case missing
        case empty
        case populated
    }

    let state: State
    let groups: [HookGroupModel]
    let restrictionBadges: [HookRestrictionBadgeModel]
    let issues: [HookIssueModel]
    let issueBadges: [IssueBadgeModel]
    let summaryNotes: [String]
    let groupCount: Int
    let rowCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int

    init(projection: SessionProjection) {
        let familyState = projection.familyStates.first(where: { $0.family == .hooks })
        guard let hooks = projection.hooks else {
            state = .missing
            groups = []
            restrictionBadges = []
            issues = []
            issueBadges = []
            groupCount = 0
            rowCount = 0
            errorCount = 0
            warningCount = 0
            infoCount = 0
            summaryNotes = SessionSettingsViewModel.deduplicated(
                projection.completeness.confidenceNotes + projection.notes
            )
            return
        }

        let eventMatchers = SessionHooksViewModel.extractEventMatchers(from: projection.settings)
        groups = hooks.events
            .map { event in
                HookGroupModel(
                    eventID: event.eventID,
                    eventType: event.eventType,
                    matcher: eventMatchers[event.eventID],
                    value: event.hooks
                )
            }
            .sorted { lhs, rhs in
                if lhs.eventType.sortKey != rhs.eventType.sortKey {
                    return lhs.eventType.sortKey < rhs.eventType.sortKey
                }
                if lhs.eventID != rhs.eventID {
                    return lhs.eventID < rhs.eventID
                }
                return lhs.matcherLabel < rhs.matcherLabel
            }
        restrictionBadges = SessionHooksViewModel.restrictionBadges(from: projection.settings)
        rowCount = groups.reduce(into: 0) { partialResult, group in
            partialResult += group.rows.count
        }
        groupCount = groups.count

        let allIssues = SessionHooksViewModel.deduplicatedIssues(
            hooks.issues +
                hooks.events.flatMap(\.hooks.issues) +
                projection.issues.filter { issue in
                    guard let keyPath = issue.keyPath else { return false }
                    return keyPath == "disableAllHooks" ||
                        keyPath == "allowManagedHooksOnly" ||
                        keyPath == "allowedHttpHookUrls" ||
                        keyPath == "httpHookAllowedEnvVars" ||
                        keyPath.hasPrefix("hooks")
                }
        )
        issues = allIssues.map(HookIssueModel.init)
        issueBadges = IssueBadgeModel.badges(for: allIssues)
        errorCount = allIssues.filter { $0.severity == .error }.count
        warningCount = allIssues.filter { $0.severity == .warning }.count
        infoCount = allIssues.filter { $0.severity == .info }.count

        state = groups.isEmpty ? .empty : .populated

        let hookCompletenessNotes = projection.completeness.confidenceNotes.filter {
            $0.localizedCaseInsensitiveContains("hooks") ||
                $0.localizedCaseInsensitiveContains("families") ||
                $0.localizedCaseInsensitiveContains("partial")
        }
        let sourceCoverageNote = groups.contains(where: { $0.rows.contains(where: { $0.winningSourceChip == nil }) })
            ? ["Some hook rows do not include winning-source details and are shown as partial provenance."]
            : []
        summaryNotes = SessionSettingsViewModel.deduplicated(
            hooks.notes + (familyState?.confidenceNotes ?? []) + hookCompletenessNotes + sourceCoverageNote
        )
    }

    var stateLabel: String {
        switch state {
        case .missing:
            return "Missing"
        case .empty:
            return "Empty"
        case .populated:
            if errorCount > 0 {
                return "Partial"
            }
            return "Populated"
        }
    }

    var stateBadgeColor: Color {
        switch state {
        case .missing:
            return .orange
        case .empty:
            return .blue
        case .populated:
            return errorCount > 0 ? .orange : .green
        }
    }

    private static func extractEventMatchers(from settings: ResolvedSettingsSnapshot?) -> [String: String] {
        guard
            let settings,
            let hooksEntry = settings.entries.first(where: { $0.keyPath == "hooks" }),
            let value = hooksEntry.value.effectiveValue,
            case let .object(rootObject) = value
        else {
            return [:]
        }

        var eventMatchers: [String: String] = [:]
        for eventID in rootObject.keys.sorted() {
            guard let eventValue = rootObject[eventID] else { continue }
            switch eventValue {
            case .object(let eventObject):
                if case let .string(matcher)? = eventObject["matcher"] {
                    eventMatchers[eventID] = matcher
                }
            default:
                continue
            }
        }
        return eventMatchers
    }

    private static func restrictionBadges(from settings: ResolvedSettingsSnapshot?) -> [HookRestrictionBadgeModel] {
        guard let settings else { return [] }

        var rows: [HookRestrictionBadgeModel] = []
        if
            let disabledEntry = settings.entries.first(where: { $0.keyPath == "disableAllHooks" }),
            disabledEntry.value.effectiveValue?.boolValue == true
        {
            rows.append(
                HookRestrictionBadgeModel(
                    title: "Hooks Disabled",
                    detail: "All hooks and any custom status line are disabled by the effective policy.",
                    tone: .warning
                )
            )
        }

        if
            let managedOnly = settings.entries.first(where: { $0.keyPath == "allowManagedHooksOnly" }),
            managedOnly.value.effectiveValue?.boolValue == true
        {
            rows.append(
                HookRestrictionBadgeModel(
                    title: "Managed Hooks Only",
                    detail: "Only managed hooks are permitted by the effective policy.",
                    tone: .warning
                )
            )
        }

        if
            let urlsEntry = settings.entries.first(where: { $0.keyPath == "allowedHttpHookUrls" }),
            let urls = urlsEntry.value.effectiveValue?.stringArrayValue,
            urls.isEmpty == false
        {
            rows.append(
                HookRestrictionBadgeModel(
                    title: "HTTP URL Allowlist",
                    detail: "\(urls.count) allowed URL pattern\(urls.count == 1 ? "" : "s") configured.",
                    tone: .info
                )
            )
        }

        if
            let varsEntry = settings.entries.first(where: { $0.keyPath == "httpHookAllowedEnvVars" }),
            let envVars = varsEntry.value.effectiveValue?.stringArrayValue,
            envVars.isEmpty == false
        {
            rows.append(
                HookRestrictionBadgeModel(
                    title: "HTTP Env Allowlist",
                    detail: "\(envVars.count) allowed environment variable\(envVars.count == 1 ? "" : "s") exposed to HTTP hooks.",
                    tone: .info
                )
            )
        }

        return rows
    }

    private static func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }
}

struct HookGroupModel: Identifiable, Equatable {
    let eventID: String
    let eventType: HookEventType
    let eventTitle: String
    let matcherLabel: String
    let capabilityBadges: [HookCapabilityBadgeModel]
    let capabilityNote: String?
    let rows: [HookRowModel]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    var id: String { "\(eventID)-\(matcherLabel)" }

    init(eventID: String, eventType: HookEventType, matcher: String?, value: ResolvedValue<[JSONValue]>) {
        self.eventID = eventID
        self.eventType = eventType
        eventTitle = eventType.canonicalName
        matcherLabel = matcher?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? matcher!
            : "(none)"
        capabilityBadges = HookCapabilityBadgeModel.badges(for: eventType)
        capabilityNote = eventType.supportsPromptErasure
            ? "Prompt erasure: a successful block result can remove the user's prompt from model context."
            : nil

        let actions = value.effectiveValue ?? []
        rows = actions.enumerated().map { pair in
            HookRowModel(index: pair.offset, payload: pair.element, value: value)
        }
        issueBadges = IssueBadgeModel.badges(for: value.issues)
        notes = SessionSettingsViewModel.deduplicated(value.trace.notes + value.notes)
    }
}

struct HookRowModel: Identifiable, Equatable {
    let id: String
    let displayIndex: Int
    let actionSummary: String
    let rawPayloadSummary: String
    let winningSourceChip: SourceChipModel?
    let participantSourceChips: [SourceChipModel]
    let overriddenSourceChips: [SourceChipModel]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    init(index: Int, payload: JSONValue, value: ResolvedValue<[JSONValue]>) {
        displayIndex = index + 1
        id = "\(displayIndex)-\(HookRowModel.formatJSON(payload))"
        actionSummary = HookRowModel.actionSummary(for: payload)
        rawPayloadSummary = HookRowModel.formatJSON(payload)
        winningSourceChip = value.winningSource.map(SourceChipModel.init)
        participantSourceChips = value.trace.participants.map(SourceChipModel.init)
        overriddenSourceChips = value.trace.overridden.map(SourceChipModel.init)
        issueBadges = IssueBadgeModel.badges(for: value.issues)
        notes = SessionSettingsViewModel.deduplicated(value.notes + value.trace.notes)
    }

    private static func actionSummary(for payload: JSONValue) -> String {
        guard case let .object(object) = payload else {
            return "Unknown action shape"
        }

        let type = object["type"]?.stringValue ?? "unknown"
        let matcher = object["matcher"]?.stringValue
        let timeout = object["timeout"]?.numberValue.map { "timeout=\(Int($0))s" }

        if let command = object["command"]?.stringValue {
            return [type, "command: \(command)", matcher.map { "matcher: \($0)" }, timeout]
                .compactMap { $0 }
                .joined(separator: " | ")
        }

        if let url = object["url"]?.stringValue {
            return [type, "url: \(url)", matcher.map { "matcher: \($0)" }, timeout]
                .compactMap { $0 }
                .joined(separator: " | ")
        }

        return [type, matcher.map { "matcher: \($0)" }, timeout]
            .compactMap { $0 }
            .joined(separator: " | ")
    }

    private static func formatJSON(_ value: JSONValue?) -> String {
        guard let value else {
            return "(unresolved)"
        }

        switch value {
        case let .string(string):
            return "\"\(string)\""
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        case let .array(array):
            if array.isEmpty {
                return "[]"
            }
            return "[\(array.map { formatJSON($0) }.joined(separator: ", "))]"
        case let .object(object):
            if object.isEmpty {
                return "{}"
            }
            let pairs = object.keys.sorted().map { key in
                "\(key): \(formatJSON(object[key]))"
            }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

struct HookCapabilityBadgeModel: Identifiable, Equatable {
    enum Tone: Equatable {
        case warning
        case info

        var color: Color {
            switch self {
            case .warning:
                return .orange
            case .info:
                return .blue
            }
        }
    }

    let title: String
    let tone: Tone

    var id: String { title }
    var color: Color { tone.color }

    static func badges(for eventType: HookEventType) -> [HookCapabilityBadgeModel] {
        var rows: [HookCapabilityBadgeModel] = []

        if eventType.isBlocking {
            rows.append(HookCapabilityBadgeModel(title: "Blocking", tone: .warning))
        }

        if eventType.supportsContextInjection {
            rows.append(HookCapabilityBadgeModel(title: "Context injection", tone: .info))
        }

        return rows
    }
}

struct HookRestrictionBadgeModel: Identifiable, Equatable {
    enum Tone: Equatable {
        case warning
        case info
    }

    let title: String
    let detail: String
    let tone: Tone

    var id: String { title }

    var color: Color {
        switch tone {
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
}

struct HookIssueModel: Identifiable, Equatable {
    let id: String
    let severity: ResolutionIssueSeverity
    let message: String
    let keyPath: String?
    let sourceLabel: String?

    var color: Color {
        switch severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    init(issue: ResolutionIssue) {
        id = issue.id
        severity = issue.severity
        message = issue.message
        keyPath = issue.keyPath
        sourceLabel = issue.source?.sourcePath ?? issue.source?.displayName ?? issue.source?.identifier
    }
}

private extension JSONValue {
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }

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

struct SessionInstructionsViewModel: Equatable {
    enum State: Equatable {
        case missing
        case empty
        case populated
    }

    let state: State
    let rootLoadOrder: [InstructionEntryRowModel]
    let entries: [InstructionEntryRowModel]
    let importRelations: [ImportRelationModel]
    let memorySections: [AutoMemorySectionModel]
    let issueSummary: InstructionIssueSummaryModel
    let summaryNotes: [String]
    let isPartial: Bool
    let startupMemoryCount: Int
    let onDemandMemoryCount: Int

    init(projection: SessionProjection) {
        let familyState = projection.familyStates.first(where: { $0.family == .instructions })
        guard let instructions = projection.instructions else {
            state = .missing
            rootLoadOrder = []
            entries = []
            importRelations = []
            memorySections = []
            startupMemoryCount = 0
            onDemandMemoryCount = 0
            issueSummary = InstructionIssueSummaryModel(issues: [])
            isPartial = false
            summaryNotes = SessionSettingsViewModel.deduplicated(
                projection.completeness.confidenceNotes + projection.notes
            )
            return
        }

        let blockIssues = instructions.orderedBlocks.flatMap(\.content.issues)
        let allIssues = SessionInstructionsViewModel.deduplicatedIssues(
            instructions.issues + instructions.composedInstructions.issues + blockIssues
        )

        let relationModels = instructions.importEdges.map { edge in
            ImportRelationModel(edge: edge)
        }
        let importTargetsByParent = Dictionary(grouping: relationModels, by: \.parentBlockID)
            .mapValues { relations in
                relations.map(\.childTitle).sorted()
            }

        let orderedEntries = instructions.orderedBlocks.map { block in
            let depth = relationModels
                .filter { $0.childBlockID == block.blockID }
                .map(\.depth)
                .min() ?? 0
            return InstructionEntryRowModel(
                blockID: block.blockID,
                title: SessionInstructionsViewModel.displayTitle(for: block.blockID),
                pathLabel: block.content.winningSource?.sourcePath ?? block.blockID,
                contentPreview: block.content.effectiveValue.map {
                    String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180))
                },
                depth: depth,
                importTargets: importTargetsByParent[block.blockID] ?? [],
                issueBadges: IssueBadgeModel.badges(for: block.content.issues),
                issues: block.content.issues
            )
        }

        rootLoadOrder = instructions.rootLoadOrder.map { source in
            InstructionEntryRowModel(
                blockID: source.sourcePath ?? source.identifier,
                title: SessionInstructionsViewModel.displayTitle(for: source.sourcePath ?? source.identifier),
                pathLabel: source.sourcePath ?? source.identifier,
                contentPreview: nil,
                depth: 0,
                importTargets: [],
                issueBadges: [],
                issues: []
            )
        }
        entries = orderedEntries
        importRelations = relationModels
        startupMemoryCount = instructions.startupMemoryTopics.count
        onDemandMemoryCount = instructions.onDemandMemoryTopics.count
        memorySections = [
            AutoMemorySectionModel(
                title: "Startup Loaded",
                rows: instructions.startupMemoryTopics.map(AutoMemoryTopicRowModel.init)
            ),
            AutoMemorySectionModel(
                title: "On-Demand Topics",
                rows: instructions.onDemandMemoryTopics.map(AutoMemoryTopicRowModel.init)
            )
        ]

        issueSummary = InstructionIssueSummaryModel(issues: allIssues)
        isPartial = (familyState?.completeness == .partial) || issueSummary.errorCount > 0

        let hasNoRows = instructions.orderedBlocks.isEmpty &&
            instructions.importEdges.isEmpty &&
            instructions.startupMemoryTopics.isEmpty &&
            instructions.onDemandMemoryTopics.isEmpty
        state = hasNoRows ? .empty : .populated

        let instructionCompletenessNotes = projection.completeness.confidenceNotes.filter {
            $0.localizedCaseInsensitiveContains("families") || $0.localizedCaseInsensitiveContains("partial")
        }
        summaryNotes = SessionSettingsViewModel.deduplicated(
            instructions.notes + (familyState?.confidenceNotes ?? []) + instructionCompletenessNotes
        )
    }

    var stateLabel: String {
        switch state {
        case .missing:
            return "Missing"
        case .empty:
            return "Empty"
        case .populated:
            return isPartial ? "Partial" : "Populated"
        }
    }

    var stateBadgeColor: Color {
        switch state {
        case .missing:
            return .orange
        case .empty:
            return .blue
        case .populated:
            return isPartial ? .orange : .green
        }
    }

    private static func displayTitle(for path: String) -> String {
        let component = URL(fileURLWithPath: path).lastPathComponent
        return component.isEmpty ? path : component
    }

    private static func deduplicatedIssues(_ issues: [ResolutionIssue]) -> [ResolutionIssue] {
        var seen = Set<String>()
        return issues.filter { seen.insert($0.id).inserted }
    }
}

struct InstructionEntryRowModel: Identifiable, Equatable {
    let blockID: String
    let title: String
    let pathLabel: String
    let contentPreview: String?
    let depth: Int
    let importTargets: [String]
    let issueBadges: [IssueBadgeModel]
    let issues: [ResolutionIssue]

    var id: String { blockID }
}

struct ImportRelationModel: Identifiable, Equatable {
    let parentBlockID: String
    let childBlockID: String?
    let parentTitle: String
    let childTitle: String
    let rawToken: String
    let resolvedPath: String?
    let depth: Int
    let isCycle: Bool
    let isResolved: Bool

    var id: String { "\(parentBlockID)-\(rawToken)-\(depth)-\(childBlockID ?? "unresolved")" }

    init(edge: ResolvedInstructionImportEdge) {
        parentBlockID = edge.parentBlockID
        childBlockID = edge.childBlockID
        parentTitle = URL(fileURLWithPath: edge.parentBlockID).lastPathComponent
        if let childBlockID = edge.childBlockID {
            childTitle = URL(fileURLWithPath: childBlockID).lastPathComponent
        } else if let resolvedPath = edge.resolvedPath {
            childTitle = URL(fileURLWithPath: resolvedPath).lastPathComponent
        } else {
            childTitle = "(unresolved)"
        }
        rawToken = edge.rawToken
        resolvedPath = edge.resolvedPath
        depth = edge.depth
        isCycle = edge.isCycle
        isResolved = edge.childBlockID != nil
    }
}

struct AutoMemorySectionModel: Identifiable, Equatable {
    let title: String
    let rows: [AutoMemoryTopicRowModel]

    var id: String { title }
}

struct AutoMemoryTopicRowModel: Identifiable, Equatable {
    let topicID: String
    let title: String
    let pathLabel: String
    let availability: ResolutionAvailability

    var id: String { topicID }
    var availabilityLabel: String { availability.rawValue }

    init(topic: ResolvedInstructionMemoryTopic) {
        topicID = topic.topicID
        title = topic.title
        pathLabel = topic.source.sourcePath ?? topic.source.identifier
        availability = topic.availability
    }
}

struct InstructionIssueSummaryModel: Equatable {
    let totalCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let cycleCount: Int
    let unresolvedImportCount: Int
    let depthLimitCount: Int
    let messagePreview: [String]

    var badges: [IssueBadgeModel] {
        IssueBadgeModel.badges(for: issues)
    }

    private let issues: [ResolutionIssue]

    init(issues: [ResolutionIssue]) {
        self.issues = issues.sorted { $0.id < $1.id }
        totalCount = issues.count
        errorCount = issues.filter { $0.severity == .error }.count
        warningCount = issues.filter { $0.severity == .warning }.count
        infoCount = issues.filter { $0.severity == .info }.count
        cycleCount = issues.filter { $0.code == .cycleDetected }.count
        unresolvedImportCount = issues.filter { $0.code == .unresolvedImport }.count
        depthLimitCount = issues.filter { $0.code == .importDepthExceeded }.count
        messagePreview = Array(issues.map(\.message).prefix(3))
    }
}

struct SessionSettingsViewModel: Equatable {
    enum State: Equatable {
        case missing
        case empty
        case populated
    }

    let state: State
    let sections: [SessionSettingsSectionModel]
    let summaryNotes: [String]
    let rowCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int

    init(projection: SessionProjection) {
        let settingsState = projection.familyStates.first(where: { $0.family == .settings })
        let settings = projection.settings

        self.errorCount = settingsState?.errorCount ?? 0
        self.warningCount = settingsState?.warningCount ?? 0
        self.infoCount = settingsState?.infoCount ?? 0

        if settings == nil {
            state = .missing
            sections = []
            rowCount = 0
            summaryNotes = SessionSettingsViewModel.deduplicated(
                projection.completeness.confidenceNotes + projection.notes
            )
            return
        }

        let rowModels = (settings?.entries ?? []).map(ResolvedSettingRowModel.init)
        let grouped = Dictionary(grouping: rowModels, by: { SessionSettingsSectionModel.sectionKey(for: $0.keyPath) })

        let sectionModels = grouped
            .keys
            .sorted()
            .map { key -> SessionSettingsSectionModel in
                let rows = (grouped[key] ?? []).sorted { $0.keyPath < $1.keyPath }
                return SessionSettingsSectionModel(
                    key: key,
                    title: SessionSettingsSectionModel.sectionTitle(for: key),
                    rows: rows,
                    issueBadges: SessionSettingsViewModel.issueBadges(rows.flatMap(\.issues)),
                    notes: SessionSettingsViewModel.deduplicated(rows.flatMap(\.notes))
                )
            }

        self.sections = sectionModels
        self.rowCount = rowModels.count
        self.state = rowModels.isEmpty ? .empty : .populated

        let combinedNotes =
            (settings?.notes ?? []) +
            (settingsState?.confidenceNotes ?? []) +
            projection.completeness.confidenceNotes.filter { $0.localizedCaseInsensitiveContains("settings") }
        self.summaryNotes = SessionSettingsViewModel.deduplicated(combinedNotes)
    }

    var stateLabel: String {
        switch state {
        case .missing:
            return "Missing"
        case .empty:
            return "Empty"
        case .populated:
            return "Populated"
        }
    }

    var stateBadgeColor: Color {
        switch state {
        case .missing:
            return .orange
        case .empty:
            return .blue
        case .populated:
            return .green
        }
    }

    static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func issueBadges(_ issues: [ResolutionIssue]) -> [IssueBadgeModel] {
        var counts: [ResolutionIssueSeverity: Int] = [.error: 0, .warning: 0, .info: 0]
        for issue in issues {
            counts[issue.severity, default: 0] += 1
        }

        let ordered: [ResolutionIssueSeverity] = [.error, .warning, .info]
        return ordered.compactMap { severity in
            let count = counts[severity, default: 0]
            guard count > 0 else { return nil }
            return IssueBadgeModel(severity: severity, count: count)
        }
    }
}

struct SessionSettingsSectionModel: Identifiable, Equatable {
    let key: String
    let title: String
    let rows: [ResolvedSettingRowModel]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    var id: String { key }

    static func sectionKey(for keyPath: String) -> String {
        guard let first = keyPath.split(separator: ".", maxSplits: 1).first else {
            return "general"
        }
        return first.isEmpty ? "general" : String(first)
    }

    static func sectionTitle(for key: String) -> String {
        if key == "general" {
            return "General"
        }

        var spaced = ""
        for character in key {
            if character.isUppercase, spaced.isEmpty == false {
                spaced.append(" ")
            }
            if character == "_" {
                spaced.append(" ")
            } else {
                spaced.append(character)
            }
        }

        let words = spaced
            .split(separator: " ")
            .map(String.init)

        if words.isEmpty {
            return key.capitalized
        }

        return words.map { $0.capitalized }.joined(separator: " ")
    }
}

struct ResolvedSettingRowModel: Identifiable, Equatable {
    let keyPath: String
    let valueDisplay: String
    let mergeMethod: MergeMethod
    let winningSourceChip: SourceChipModel?
    let participantSourceChips: [SourceChipModel]
    let overriddenSourceChips: [SourceChipModel]
    let issues: [ResolutionIssue]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    var id: String { keyPath }

    var mergeMethodLabel: String {
        switch mergeMethod {
        case .selectHighestPrecedence:
            return "Select Highest"
        case .replace:
            return "Replace"
        case .deepMergeObject:
            return "Deep Merge"
        case .append:
            return "Append"
        case .appendUnique:
            return "Append Unique"
        case .setUnion:
            return "Set Union"
        case .keyedByIdentifier:
            return "Keyed Merge"
        case .passthrough:
            return "Passthrough"
        }
    }

    init(entry: ResolvedSettingsEntry) {
        keyPath = entry.keyPath
        valueDisplay = Self.formatJSON(entry.value.effectiveValue)
        mergeMethod = entry.value.mergeMethod
        winningSourceChip = entry.value.winningSource.map(SourceChipModel.init)
        participantSourceChips = entry.value.trace.participants.map(SourceChipModel.init)
        overriddenSourceChips = entry.value.trace.overridden.map(SourceChipModel.init)
        issues = entry.value.issues
        issueBadges = Self.issueBadges(entry.value.issues)
        notes = SessionSettingsViewModel.deduplicated(entry.value.trace.notes + entry.value.notes)
    }

    private static func issueBadges(_ issues: [ResolutionIssue]) -> [IssueBadgeModel] {
        var counts: [ResolutionIssueSeverity: Int] = [.error: 0, .warning: 0, .info: 0]
        for issue in issues {
            counts[issue.severity, default: 0] += 1
        }

        let ordered: [ResolutionIssueSeverity] = [.error, .warning, .info]
        return ordered.compactMap { severity in
            let count = counts[severity, default: 0]
            guard count > 0 else { return nil }
            return IssueBadgeModel(severity: severity, count: count)
        }
    }

    private static func formatJSON(_ value: JSONValue?) -> String {
        guard let value else {
            return "(unresolved)"
        }

        switch value {
        case let .string(string):
            return "\"\(string)\""
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        case let .array(array):
            if array.isEmpty {
                return "[]"
            }
            return "[\(array.map { formatJSON($0) }.joined(separator: ", "))]"
        case let .object(object):
            if object.isEmpty {
                return "{}"
            }
            let pairs = object.keys.sorted().map { key in
                "\(key): \(formatJSON(object[key]))"
            }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

struct SourceChipModel: Identifiable, Equatable {
    let id: String
    let label: String
    let availability: ResolutionAvailability

    init(source: ResolutionSource) {
        id = source.id
        availability = source.availability

        if let path = source.sourcePath {
            label = path
            return
        }

        if let displayName = source.displayName, !displayName.isEmpty {
            label = displayName
            return
        }

        label = source.identifier
    }
}

struct IssueBadgeModel: Identifiable, Equatable {
    let severity: ResolutionIssueSeverity
    let count: Int

    var id: String { "\(severity.rawValue)-\(count)" }

    var label: String {
        switch severity {
        case .error:
            return "error"
        case .warning:
            return "warning"
        case .info:
            return "info"
        }
    }

    var color: Color {
        switch severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    init(severity: ResolutionIssueSeverity, count: Int) {
        self.severity = severity
        self.count = count
    }

    static func badges(for issues: [ResolutionIssue]) -> [IssueBadgeModel] {
        var counts: [ResolutionIssueSeverity: Int] = [.error: 0, .warning: 0, .info: 0]
        for issue in issues {
            counts[issue.severity, default: 0] += 1
        }

        let ordered: [ResolutionIssueSeverity] = [.error, .warning, .info]
        return ordered.compactMap { severity in
            let count = counts[severity, default: 0]
            guard count > 0 else { return nil }
            return IssueBadgeModel(severity: severity, count: count)
        }
    }
}
