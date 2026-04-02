import SwiftUI

struct ManagedScopeView: View {
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    /// Incremented after a bookmark grant to force viewModel re-creation.
    @State private var inspectionGeneration = 0

    private var viewModel: ManagedScopeViewModel {
        // Capture the generation to create a data dependency so SwiftUI
        // rebuilds when inspectionGeneration changes.
        _ = inspectionGeneration
        return ManagedScopeViewModel()
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard(vm)

                if vm.status.accessOutcome.requiresExplicitFallbackUI {
                    accessFallbackCard(vm)
                }

                activeTierCard(vm)
                tierStatusCard(vm)
                fileSourcesCard(vm)
                managedSettingsCard(vm)
                managedMcpCard(vm)
                managedClaudeMdCard(vm)
                ScopeContributionSummaryView(targetScope: .managed)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Managed")
    }

    private func headerCard(_ viewModel: ManagedScopeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Managed Configuration", systemImage: "building.2.crop.circle")
                .font(.largeTitle.weight(.semibold))

            Text("Inspect the managed-policy surface read-only. Only one managed settings tier is active at a time: server-managed, then MDM / OS policy, then file-based managed settings.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func accessFallbackCard(_ viewModel: ManagedScopeViewModel) -> some View {
        let outcome = viewModel.status.accessOutcome
        let tint = accessFallbackTint(outcome)

        VStack(alignment: .leading, spacing: 12) {
            Label(accessFallbackTitle(outcome), systemImage: accessFallbackIcon(outcome))
                .font(.headline)
                .foregroundStyle(tint)

            Text(accessFallbackMessage(outcome))
                .foregroundStyle(.secondary)

            if case .sandboxRestricted = outcome {
                Button {
                    rootSelection.authorizeManagedRoot()
                    inspectionGeneration += 1
                } label: {
                    Label("Grant Access", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if case .inaccessible(let diagnostics) = outcome,
               let diagnostics {
                Divider()
                Text(diagnostics)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accessFallbackBackground(outcome), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.35))
        )
    }

    private func accessFallbackTitle(_ outcome: ManagedAccessOutcome) -> String {
        switch outcome {
        case .sandboxRestricted:
            return "Managed path not accessible in sandbox"
        case .inaccessible:
            return "Managed path inaccessible"
        default:
            return "Managed path unavailable"
        }
    }

    private func accessFallbackIcon(_ outcome: ManagedAccessOutcome) -> String {
        switch outcome {
        case .sandboxRestricted:
            return "lock.shield"
        case .inaccessible:
            return "exclamationmark.triangle"
        default:
            return "exclamationmark.circle"
        }
    }

    private func accessFallbackMessage(_ outcome: ManagedAccessOutcome) -> String {
        switch outcome {
        case .sandboxRestricted:
            return "This build cannot inspect /Library/Application Support/ClaudeCode/ from inside the macOS sandbox. Grant access below to allow read-only inspection of managed settings."
        case .inaccessible:
            return "The managed ClaudeCode directory exists but could not be read. Check filesystem permissions or any endpoint security restrictions."
        default:
            return "The managed configuration path is not accessible."
        }
    }

    private func accessFallbackTint(_ outcome: ManagedAccessOutcome) -> Color {
        switch outcome {
        case .sandboxRestricted:
            return .orange
        case .inaccessible:
            return .red
        default:
            return .yellow
        }
    }

    private func accessFallbackBackground(_ outcome: ManagedAccessOutcome) -> AnyShapeStyle {
        switch outcome {
        case .sandboxRestricted:
            return AnyShapeStyle(.orange.opacity(0.06))
        case .inaccessible:
            return AnyShapeStyle(.red.opacity(0.06))
        default:
            return AnyShapeStyle(.yellow.opacity(0.06))
        }
    }

    private func activeTierCard(_ viewModel: ManagedScopeViewModel) -> some View {
        let status = viewModel.status
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(status.title)
                    .font(.headline)
                Spacer()
                statusBadge(label: status.activeTierLabel == "none" ? "None" : status.detail, style: status.activeTierLabel == "none" ? .absent : .active)
            }

            Text(status.detail)
                .foregroundStyle(.secondary)

            if !status.sourceSummaries.isEmpty {
                Divider()

                ForEach(status.sourceSummaries, id: \.self) { summary in
                    Label(summary, systemImage: "doc.text")
                        .font(.subheadline)
                }
            }

            if !viewModel.notes.isEmpty {
                Divider()
                ForEach(viewModel.notes, id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

    private func tierStatusCard(_ viewModel: ManagedScopeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Managed tier status")
                .font(.headline)

            ForEach(viewModel.tierRows) { row in
                rowCard(
                    title: row.title,
                    detail: row.detail,
                    status: row.statusStyle,
                    secondaryText: row.sourceSummary
                )
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

    private func fileSourcesCard(_ viewModel: ManagedScopeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Discovered managed sources")
                .font(.headline)

            ForEach(viewModel.fileSourceRows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.subheadline.weight(.semibold))
                            Text(row.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        statusBadge(label: row.statusStyle.label, style: row.statusStyle)
                    }

                    Text(row.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func managedSettingsCard(_ viewModel: ManagedScopeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Managed Settings")
                    .font(.headline)
                Spacer()
                if !viewModel.settingsEntries.isEmpty {
                    Text("\(viewModel.settingsEntries.count) setting\(viewModel.settingsEntries.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ScopeColorScheme.color(for: .managed).opacity(0.18), in: Capsule())
                        .foregroundStyle(ScopeColorScheme.color(for: .managed))
                }
            }

            if viewModel.settingsEntries.isEmpty {
                Text("No managed settings are currently active. Managed policy would override all user and project configuration.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else {
                ForEach(viewModel.settingsEntries) { entry in
                    managedSettingsEntryRow(entry)
                }
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

    private func managedSettingsEntryRow(_ entry: ManagedScopeViewModel.ManagedSettingsEntryRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(ScopeColorScheme.color(for: .managed))

                        Text(entry.keyPath)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    }

                    Text(entry.valueDisplay)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                Spacer()
                Text(entry.subTierLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ScopeColorScheme.color(for: .managed).opacity(0.18), in: Capsule())
                    .foregroundStyle(ScopeColorScheme.color(for: .managed))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func managedMcpCard(_ viewModel: ManagedScopeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Managed MCP")
                    .font(.headline)
                Spacer()
                statusBadge(label: viewModel.managedMcp.statusStyle.label, style: viewModel.managedMcp.statusStyle)
            }

            Text(viewModel.managedMcp.detail)
                .foregroundStyle(.secondary)

            if !viewModel.managedMcp.serverIDs.isEmpty {
                Divider()
                Text(viewModel.managedMcp.serverIDs.joined(separator: ", "))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
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

    private func managedClaudeMdCard(_ viewModel: ManagedScopeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Managed CLAUDE.md")
                    .font(.headline)
                Spacer()
                statusBadge(label: viewModel.managedClaudeMd.statusStyle.label, style: viewModel.managedClaudeMd.statusStyle)
            }

            Text(viewModel.managedClaudeMd.detail)
                .foregroundStyle(.secondary)

            if viewModel.managedClaudeMd.importCount > 0 {
                Text("Imports detected: \(viewModel.managedClaudeMd.importCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let content = viewModel.managedClaudeMd.content {
                Divider()
                ScrollView(.vertical) {
                    Text(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(minHeight: 160, maxHeight: 320)
            }

            if !viewModel.managedClaudeMd.issueMessages.isEmpty {
                Divider()
                ForEach(viewModel.managedClaudeMd.issueMessages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private func rowCard(
        title: String,
        detail: String,
        status: ManagedScopeViewModel.StatusStyle,
        secondaryText: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                statusBadge(label: status.label, style: status)
            }

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let secondaryText, !secondaryText.isEmpty {
                Text(secondaryText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusBadge(label: String, style: ManagedScopeViewModel.StatusStyle) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badgeColor(style).opacity(0.18), in: Capsule())
            .foregroundStyle(badgeColor(style))
    }

    private func badgeColor(_ style: ManagedScopeViewModel.StatusStyle) -> Color {
        switch style {
        case .active:
            return .green
        case .available:
            return .blue
        case .suppressed:
            return .orange
        case .absent:
            return .secondary
        case .inaccessible:
            return .red
        }
    }
}

struct ManagedScopeViewModel: Equatable {
    enum StatusStyle: String, Equatable {
        case active
        case available
        case suppressed
        case absent
        case inaccessible

        var label: String {
            switch self {
            case .active:
                return "Active"
            case .available:
                return "Available"
            case .suppressed:
                return "Suppressed"
            case .absent:
                return "Absent"
            case .inaccessible:
                return "Inaccessible"
            }
        }
    }

    struct TierRow: Equatable, Identifiable {
        let title: String
        let statusStyle: StatusStyle
        let detail: String
        let sourceSummary: String?

        var id: String { title }
    }

    struct SourceRow: Equatable, Identifiable {
        let title: String
        let path: String
        let statusStyle: StatusStyle
        let detail: String

        var id: String { path }
    }

    struct ManagedMcpSummary: Equatable {
        let statusStyle: StatusStyle
        let detail: String
        let serverIDs: [String]
    }

    struct ManagedClaudeMdSummary: Equatable {
        let statusStyle: StatusStyle
        let detail: String
        let content: String?
        let importCount: Int
        let issueMessages: [String]
    }

    struct ManagedSettingsEntryRow: Equatable, Identifiable {
        let keyPath: String
        let valueDisplay: String
        let subTierLabel: String
        let sourcePath: String

        var id: String { keyPath }
    }

    let status: ManagedScopeStatusModel
    let tierRows: [TierRow]
    let fileSourceRows: [SourceRow]
    let managedMcp: ManagedMcpSummary
    let managedClaudeMd: ManagedClaudeMdSummary
    let settingsEntries: [ManagedSettingsEntryRow]
    let notes: [String]

    init(inspector: ManagedScopeInspecting = ManagedScopeInspector()) {
        self = inspector.inspect()
    }

    init(
        status: ManagedScopeStatusModel,
        tierRows: [TierRow],
        fileSourceRows: [SourceRow],
        managedMcp: ManagedMcpSummary,
        managedClaudeMd: ManagedClaudeMdSummary,
        settingsEntries: [ManagedSettingsEntryRow],
        notes: [String]
    ) {
        self.status = status
        self.tierRows = tierRows
        self.fileSourceRows = fileSourceRows
        self.managedMcp = managedMcp
        self.managedClaudeMd = managedClaudeMd
        self.settingsEntries = settingsEntries
        self.notes = notes
    }
}

protocol ManagedScopeInspecting {
    func inspect() -> ManagedScopeViewModel
}

struct ManagedScopeInspector: ManagedScopeInspecting {
    private let managedSettingsLocator: ManagedSettingsLocator
    private let sandboxProbe: SandboxProbing
    private let mdmPolicyReader: MDMPolicyReading
    private let settingsParser: SettingsParser
    private let claudeJsonParser: ClaudeJsonParser
    private let claudeMdParser: ClaudeMdParser
    private let dataLoader: @Sendable (URL) throws -> Data
    private let managedSettingsResolver: ManagedSettingsResolver

    init(
        managedSettingsLocator: ManagedSettingsLocator = ManagedSettingsLocator(),
        sandboxProbe: SandboxProbing = SystemSandboxProbe(),
        mdmPolicyReader: MDMPolicyReading = MDMPolicyReader(),
        settingsParser: SettingsParser = SettingsParser(),
        claudeJsonParser: ClaudeJsonParser = ClaudeJsonParser(),
        claudeMdParser: ClaudeMdParser = ClaudeMdParser(),
        dataLoader: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        managedSettingsResolver: ManagedSettingsResolver = ManagedSettingsResolver()
    ) {
        self.managedSettingsLocator = managedSettingsLocator
        self.sandboxProbe = sandboxProbe
        self.mdmPolicyReader = mdmPolicyReader
        self.settingsParser = settingsParser
        self.claudeJsonParser = claudeJsonParser
        self.claudeMdParser = claudeMdParser
        self.dataLoader = dataLoader
        self.managedSettingsResolver = managedSettingsResolver
    }

    func inspect() -> ManagedScopeViewModel {
        let accessOutcome = managedSettingsLocator.probeManagedAccessOutcome(sandboxProbe: sandboxProbe)
        let snapshot = managedSettingsLocator.discoverySnapshot()
        let mdmCandidate = buildMdmCandidate()
        let fileBasedCandidates = buildFileBasedSettingsCandidates(snapshot: snapshot)
        let managedMcpDocument = buildManagedMcpCandidate(snapshot: snapshot)
        let managedClaudeMd = buildManagedClaudeMdSummary(snapshot: snapshot, accessOutcome: accessOutcome)

        let resolution = managedSettingsResolver.resolve(
            input: ManagedSettingsResolver.Input(
                mdmManagedSettings: mdmCandidate,
                fileBasedSettings: fileBasedCandidates,
                fileBasedManagedMcp: managedMcpDocument
            )
        )

        let status = ManagedScopeStatusModel(resolution: resolution, accessOutcome: accessOutcome)
        let tierRows = buildTierRows(
            resolution: resolution,
            mdmCandidate: mdmCandidate,
            fileBasedCandidates: fileBasedCandidates,
            accessOutcome: accessOutcome
        )
        let fileRows = buildFileRows(
            snapshot: snapshot,
            accessOutcome: accessOutcome,
            managedMcpDocument: managedMcpDocument,
            managedClaudeMd: managedClaudeMd
        )
        let settingsEntries = buildManagedSettingsEntries(resolution: resolution)

        return ManagedScopeViewModel(
            status: status,
            tierRows: tierRows,
            fileSourceRows: fileRows,
            managedMcp: buildManagedMcpSummary(document: managedMcpDocument, accessOutcome: accessOutcome, snapshot: snapshot),
            managedClaudeMd: managedClaudeMd,
            settingsEntries: settingsEntries,
            notes: resolution.notes
        )
    }

    private func buildTierRows(
        resolution: ManagedSettingsResolution,
        mdmCandidate: SettingsSourceCandidate?,
        fileBasedCandidates: [SettingsSourceCandidate],
        accessOutcome: ManagedAccessOutcome
    ) -> [ManagedScopeViewModel.TierRow] {
        let activeTierKind = resolution.activeTier?.kind

        let serverManagedRow = ManagedScopeViewModel.TierRow(
            title: "Server-managed settings",
            statusStyle: activeTierKind == .serverManaged ? .active : .absent,
            detail: activeTierKind == .serverManaged
                ? "This highest-precedence managed tier is active."
                : "No server-managed payload is available to the local inspector.",
            sourceSummary: resolution.activeTier?.kind == .serverManaged ? resolution.activeTier?.sources.map(sourceLabel).joined(separator: ", ") : nil
        )

        let mdmRow: ManagedScopeViewModel.TierRow = {
            guard let mdmCandidate else {
                return ManagedScopeViewModel.TierRow(
                    title: "MDM / OS policy",
                    statusStyle: .absent,
                    detail: "No values were found in the com.anthropic.claudecode managed preferences domain.",
                    sourceSummary: nil
                )
            }

            if activeTierKind == .mdmPolicy {
                return ManagedScopeViewModel.TierRow(
                    title: "MDM / OS policy",
                    statusStyle: .active,
                    detail: "This managed tier is active and suppresses file-based managed settings.",
                    sourceSummary: sourceLabel(mdmCandidate.source)
                )
            }

            return ManagedScopeViewModel.TierRow(
                title: "MDM / OS policy",
                statusStyle: activeTierKind == .serverManaged ? .suppressed : .available,
                detail: activeTierKind == .serverManaged
                    ? "MDM policy was found, but server-managed settings take precedence."
                    : "MDM policy was detected but is not the active managed tier.",
                sourceSummary: sourceLabel(mdmCandidate.source)
            )
        }()

        let fileBasedRow: ManagedScopeViewModel.TierRow = {
            guard !fileBasedCandidates.isEmpty else {
                let detail: String
                let style: ManagedScopeViewModel.StatusStyle
                switch accessOutcome {
                case .sandboxRestricted, .inaccessible:
                    detail = "The managed filesystem tier could not be fully inspected because the managed root path is inaccessible."
                    style = .inaccessible
                case .accessible, .missing:
                    detail = "No readable file-based managed settings were found."
                    style = .absent
                }
                return ManagedScopeViewModel.TierRow(
                    title: "File-based managed settings",
                    statusStyle: style,
                    detail: detail,
                    sourceSummary: nil
                )
            }

            let summary = fileBasedCandidates.map { sourceLabel($0.source) }.joined(separator: ", ")
            if activeTierKind == .fileBased {
                return ManagedScopeViewModel.TierRow(
                    title: "File-based managed settings",
                    statusStyle: .active,
                    detail: "This tier is active. managed-settings.json loads before drop-ins, and later drop-ins override earlier ones.",
                    sourceSummary: summary
                )
            }

            return ManagedScopeViewModel.TierRow(
                title: "File-based managed settings",
                statusStyle: .suppressed,
                detail: "File-based managed settings were found, but a higher managed tier is active.",
                sourceSummary: summary
            )
        }()

        return [serverManagedRow, mdmRow, fileBasedRow]
    }

    private func buildFileRows(
        snapshot: ManagedSettingsDiscoverySnapshot,
        accessOutcome: ManagedAccessOutcome,
        managedMcpDocument: McpDocumentCandidate?,
        managedClaudeMd: ManagedScopeViewModel.ManagedClaudeMdSummary
    ) -> [ManagedScopeViewModel.SourceRow] {
        var rows: [ManagedScopeViewModel.SourceRow] = []

        rows.append(
            fileRow(
                title: "managed-settings.json",
                file: snapshot.settingsFile,
                accessOutcome: accessOutcome,
                presentDetail: "Primary file-based managed settings file."
            )
        )

        rows.append(
            contentsOf: snapshot.dropInFiles.map { file in
                fileRow(
                    title: file.url.lastPathComponent,
                    file: file,
                    accessOutcome: accessOutcome,
                    presentDetail: "Managed settings drop-in fragment."
                )
            }
        )

        rows.append(
            fileRow(
                title: "managed-mcp.json",
                file: snapshot.mcpFile,
                accessOutcome: accessOutcome,
                presentDetail: managedMcpDocument.map {
                    let count = $0.servers.count
                    return count == 1 ? "1 managed MCP server declared." : "\(count) managed MCP servers declared."
                } ?? "Managed MCP configuration file."
            )
        )

        rows.append(
            ManagedScopeViewModel.SourceRow(
                title: "CLAUDE.md",
                path: snapshot.claudeMdFile.url.path,
                statusStyle: managedClaudeMd.statusStyle,
                detail: managedClaudeMd.detail
            )
        )

        return rows
    }

    private func buildManagedMcpSummary(
        document: McpDocumentCandidate?,
        accessOutcome: ManagedAccessOutcome,
        snapshot: ManagedSettingsDiscoverySnapshot
    ) -> ManagedScopeViewModel.ManagedMcpSummary {
        let effectiveStatus = effectiveStatus(for: snapshot.mcpFile.status, accessOutcome: accessOutcome)

        switch effectiveStatus {
        case .active, .available:
            let serverIDs = document?.servers.map(\.serverID).sorted() ?? []
            let detail: String
            if serverIDs.isEmpty {
                detail = "The managed MCP file is present, but no servers were parsed."
            } else {
                detail = serverIDs.count == 1
                    ? "1 managed MCP server is configured."
                    : "\(serverIDs.count) managed MCP servers are configured."
            }
            return ManagedScopeViewModel.ManagedMcpSummary(
                statusStyle: .available,
                detail: detail,
                serverIDs: serverIDs
            )
        case .absent:
            return ManagedScopeViewModel.ManagedMcpSummary(
                statusStyle: .absent,
                detail: "No managed MCP file was found.",
                serverIDs: []
            )
        case .suppressed:
            return ManagedScopeViewModel.ManagedMcpSummary(
                statusStyle: .suppressed,
                detail: "Managed MCP was suppressed by a higher managed tier.",
                serverIDs: []
            )
        case .inaccessible:
            return ManagedScopeViewModel.ManagedMcpSummary(
                statusStyle: .inaccessible,
                detail: "The managed MCP file could not be inspected.",
                serverIDs: []
            )
        }
    }

    private func buildManagedClaudeMdSummary(
        snapshot: ManagedSettingsDiscoverySnapshot,
        accessOutcome: ManagedAccessOutcome
    ) -> ManagedScopeViewModel.ManagedClaudeMdSummary {
        let effectiveStatus = effectiveStatus(for: snapshot.claudeMdFile.status, accessOutcome: accessOutcome)

        guard effectiveStatus == .active || effectiveStatus == .available else {
            let detail: String
            switch effectiveStatus {
            case .absent:
                detail = "No managed CLAUDE.md file was found at /Library/Application Support/ClaudeCode/CLAUDE.md."
            case .suppressed:
                detail = "Managed CLAUDE.md is present but currently suppressed."
            case .inaccessible:
                detail = "The managed CLAUDE.md path could not be inspected."
            case .active, .available:
                detail = ""
            }
            return ManagedScopeViewModel.ManagedClaudeMdSummary(
                statusStyle: effectiveStatus == .active ? .active : effectiveStatus,
                detail: detail,
                content: nil,
                importCount: 0,
                issueMessages: []
            )
        }

        do {
            let data = try dataLoader(snapshot.claudeMdFile.url)
            let parseResult = claudeMdParser.parse(data: data, sourceURL: snapshot.claudeMdFile.url)
            let content = parseResult.value?.rawBody ?? String(decoding: data, as: UTF8.self)
            return ManagedScopeViewModel.ManagedClaudeMdSummary(
                statusStyle: .available,
                detail: "This instruction source applies to all Claude Code sessions on this machine.",
                content: content,
                importCount: parseResult.value?.imports.filter { $0.status == .valid }.count ?? 0,
                issueMessages: parseResult.issues.map(\.message)
            )
        } catch {
            return ManagedScopeViewModel.ManagedClaudeMdSummary(
                statusStyle: .inaccessible,
                detail: "The managed CLAUDE.md file exists but could not be read.",
                content: nil,
                importCount: 0,
                issueMessages: [error.localizedDescription]
            )
        }
    }

    private func fileRow(
        title: String,
        file: ManagedSettingsDiscoveryFile,
        accessOutcome: ManagedAccessOutcome,
        presentDetail: String
    ) -> ManagedScopeViewModel.SourceRow {
        let statusStyle = effectiveStatus(for: file.status, accessOutcome: accessOutcome)
        let detail: String

        switch statusStyle {
        case .active, .available:
            detail = presentDetail
        case .suppressed:
            detail = "This source is present but not participating because a higher managed tier is active."
        case .absent:
            detail = "This source was not found."
        case .inaccessible:
            detail = "This source could not be inspected."
        }

        return ManagedScopeViewModel.SourceRow(
            title: title,
            path: file.url.path,
            statusStyle: statusStyle == .active ? .available : statusStyle,
            detail: detail
        )
    }

    private func buildManagedSettingsEntries(
        resolution: ManagedSettingsResolution
    ) -> [ManagedScopeViewModel.ManagedSettingsEntryRow] {
        let candidates = resolution.settingsCandidates
        guard !candidates.isEmpty else {
            return []
        }

        var entries: [ManagedScopeViewModel.ManagedSettingsEntryRow] = []
        var seenKeys = Set<String>()

        for candidate in candidates {
            guard let document = candidate.document else { continue }

            for (key, value) in document.rawTopLevelObject.sorted(by: { $0.key < $1.key }) {
                guard !seenKeys.contains(key) else { continue }
                seenKeys.insert(key)

                let subTierLabel: String = {
                    if candidate.source.kind == .managed && candidate.source.sourcePath == MDMPolicyReader.managedPolicyDomain {
                        return "MDM"
                    }
                    if candidate.source.sourcePath?.contains("/managed-settings.d/") == true {
                        return "File"
                    }
                    if candidate.source.sourcePath?.contains("/managed-settings.json") == true {
                        return "File"
                    }
                    return "Server"
                }()

                let valueDisplay = Self.displayValue(value, maxLength: 100)
                let sourcePath = candidate.source.sourcePath ?? candidate.source.identifier

                entries.append(ManagedScopeViewModel.ManagedSettingsEntryRow(
                    keyPath: key,
                    valueDisplay: valueDisplay,
                    subTierLabel: subTierLabel,
                    sourcePath: sourcePath
                ))
            }
        }

        return entries.sorted { $0.keyPath < $1.keyPath }
    }

    private static func displayValue(_ value: JSONValue, maxLength: Int = 100) -> String {
        let description: String = {
            switch value {
            case .null:
                return "null"
            case .bool(let b):
                return b ? "true" : "false"
            case .number(let n):
                return String(n)
            case .string(let s):
                return "\"\(s)\""
            case .array(let a):
                return "[\(a.count) item\(a.count == 1 ? "" : "s")]"
            case .object(let o):
                return "{\(o.count) key\(o.count == 1 ? "" : "s")}"
            }
        }()

        if description.count > maxLength {
            return String(description.prefix(maxLength - 3)) + "..."
        }
        return description
    }

    private func buildFileBasedSettingsCandidates(
        snapshot: ManagedSettingsDiscoverySnapshot
    ) -> [SettingsSourceCandidate] {
        let files = [snapshot.settingsFile] + snapshot.dropInFiles

        return files.compactMap { file in
            guard file.status == .readableFile else {
                return nil
            }

            let identifier = file.url.deletingPathExtension().lastPathComponent
            return settingsCandidate(url: file.url, identifier: identifier)
        }
    }

    private func buildMdmCandidate() -> SettingsSourceCandidate? {
        let parseResult = mdmPolicyReader.readPolicies()
        guard let policies = parseResult.value, !policies.isEmpty else {
            return nil
        }

        let source = ResolutionSource(
            scope: .managed,
            kind: .managed,
            identifier: "mdm-managed",
            displayName: MDMPolicyReader.managedPolicyDomain,
            sourcePath: MDMPolicyReader.managedPolicyDomain,
            availability: .present
        )

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject(from: .object(policies)))
            let parsed = settingsParser.parse(
                data: jsonData,
                sourceURL: URL(fileURLWithPath: "/virtual/\(MDMPolicyReader.managedPolicyDomain).json"),
                scope: .managed
            )
            return SettingsSourceCandidate(
                tier: .managed,
                source: source,
                document: parsed.value,
                issues: parseResult.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) } + parsed.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
            )
        } catch {
            return SettingsSourceCandidate(
                tier: .managed,
                source: source,
                document: nil,
                issues: [
                    ResolutionIssue(
                        code: .invalidSource,
                        severity: .error,
                        message: "MDM policy could not be normalized into JSON: \(error.localizedDescription)",
                        source: source
                    )
                ] + parseResult.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
            )
        }
    }

    private func buildManagedMcpCandidate(
        snapshot: ManagedSettingsDiscoverySnapshot
    ) -> McpDocumentCandidate? {
        guard snapshot.mcpFile.status == .readableFile else {
            return nil
        }

        let source = ResolutionSource(
            scope: .managed,
            kind: .managed,
            identifier: "managed-mcp",
            displayName: "managed-mcp.json",
            sourcePath: snapshot.mcpFile.url.path,
            availability: .present
        )

        do {
            let data = try dataLoader(snapshot.mcpFile.url)
            let wrappedJson = try wrapManagedMcpDataAsClaudeJson(data)
            let parseResult = claudeJsonParser.parse(jsonString: wrappedJson, sourceURL: snapshot.mcpFile.url)
            let servers = parseResult.value?.value.mcpState?.localServers ?? [:]
            let serverEntries = servers.keys.sorted().enumerated().map { index, serverID in
                McpDocumentServerEntry(
                    serverID: serverID,
                    rawConfig: .object(servers[serverID]?.rawObject ?? [:]),
                    parseOrder: index
                )
            }
            return McpDocumentCandidate(
                tier: .managed,
                source: source,
                servers: serverEntries,
                issues: parseResult.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
            )
        } catch {
            return McpDocumentCandidate(
                tier: .managed,
                source: source,
                servers: [],
                issues: [
                    ResolutionIssue(
                        code: .invalidSource,
                        severity: .error,
                        message: "managed-mcp.json could not be read: \(error.localizedDescription)",
                        source: source
                    )
                ]
            )
        }
    }

    private func settingsCandidate(url: URL, identifier: String) -> SettingsSourceCandidate? {
        let source = ResolutionSource(
            scope: .managed,
            kind: .managed,
            identifier: identifier,
            displayName: url.lastPathComponent,
            sourcePath: url.path,
            availability: .present
        )

        do {
            let data = try dataLoader(url)
            let parsed = settingsParser.parse(data: data, sourceURL: url, scope: .managed)
            return SettingsSourceCandidate(
                tier: .managed,
                source: source,
                document: parsed.value,
                issues: parsed.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
            )
        } catch {
            return SettingsSourceCandidate(
                tier: .managed,
                source: source,
                document: nil,
                issues: [
                    ResolutionIssue(
                        code: .inaccessibleSource,
                        severity: .error,
                        message: "Managed settings file could not be read: \(error.localizedDescription)",
                        source: source
                    )
                ]
            )
        }
    }

    private func wrapManagedMcpDataAsClaudeJson(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = object as? [String: Any] else {
            throw NSError(domain: "ManagedScopeInspector", code: 1, userInfo: [NSLocalizedDescriptionKey: "managed-mcp.json must contain a top-level object"])
        }

        let serverObject: [String: Any]
        if let mcpServers = root["mcpServers"] as? [String: Any] {
            serverObject = mcpServers
        } else {
            serverObject = root
        }

        let wrapped: [String: Any] = [
            "mcp": [
                "local": serverObject
            ]
        ]
        let wrappedData = try JSONSerialization.data(withJSONObject: wrapped, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: wrappedData, as: UTF8.self)
    }

    private func effectiveStatus(
        for nodeStatus: ManagedSettingsNodeStatus,
        accessOutcome: ManagedAccessOutcome
    ) -> ManagedScopeViewModel.StatusStyle {
        switch nodeStatus {
        case .readableFile, .readableDirectory:
            return .available
        case .missing:
            switch accessOutcome {
            case .sandboxRestricted, .inaccessible:
                return .inaccessible
            case .accessible, .missing:
                return .absent
            }
        case .unreadableFile, .unreadableDirectory, .unsupported:
            return .inaccessible
        }
    }

    private func sourceLabel(_ source: ResolutionSource) -> String {
        source.displayName ?? source.sourcePath ?? source.identifier
    }

    private func jsonObject(from value: JSONValue) -> Any {
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            return number
        case .bool(let bool):
            return bool
        case .object(let object):
            return object.mapValues(jsonObject(from:))
        case .array(let array):
            return array.map(jsonObject(from:))
        case .null:
            return NSNull()
        }
    }
}
