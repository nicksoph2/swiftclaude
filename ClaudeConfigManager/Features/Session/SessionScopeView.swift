import SwiftUI

struct SessionScopeView: View {
    private enum SessionPanel: String, CaseIterable, Identifiable {
        case settings
        case instructions
        case hooks

        var id: String { rawValue }

        var title: String {
            switch self {
            case .settings:
                return "Settings"
            case .instructions:
                return "Instructions"
            case .hooks:
                return "Hooks"
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
            }
        }
        .onAppear {
            debugMonitor.recordDetail(
                title: "Session",
                subtitle: "Read-only effective settings and instructions with provenance.",
                debugNotes: [
                    "Projection-driven settings view (F1).",
                    "Projection-driven instructions view (F2).",
                    "Projection-driven hooks view (F3).",
                    "Settings availability: \(projection.familyStates.first(where: { $0.family == .settings })?.availability.rawValue ?? "unknown")",
                    "Instructions availability: \(projection.familyStates.first(where: { $0.family == .instructions })?.availability.rawValue ?? "unknown")",
                    "Hooks availability: \(projection.familyStates.first(where: { $0.family == .hooks })?.availability.rawValue ?? "unknown")",
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
                                        "timeoutMs": .number(1500)
                                    ])
                                ])
                            ]),
                            "postToolUse": .array([
                                .object([
                                    "type": .string("http"),
                                    "url": .string("https://hooks.example.internal/post-tool"),
                                    "timeoutMs": .number(3000)
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

        return SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(
                settings: settings,
                instructions: instructions,
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
                    matcher: eventMatchers[event.eventID],
                    value: event.hooks
                )
            }
            .sorted { lhs, rhs in
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
                    return keyPath == "allowManagedHooksOnly" ||
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
    let eventTitle: String
    let matcherLabel: String
    let rows: [HookRowModel]
    let issueBadges: [IssueBadgeModel]
    let notes: [String]

    var id: String { "\(eventID)-\(matcherLabel)" }

    init(eventID: String, matcher: String?, value: ResolvedValue<[JSONValue]>) {
        self.eventID = eventID
        eventTitle = eventID
        matcherLabel = matcher?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? matcher!
            : "(none)"

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
        let timeout = object["timeoutMs"]?.numberValue.map { "timeout=\(Int($0))ms" }

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
