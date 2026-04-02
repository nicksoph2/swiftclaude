import SwiftUI

// MARK: - Identifiable wrapper for sheet presentation

private struct IdentifiableSettingsEntry: Identifiable {
    let entry: ResolvedSettingsEntry
    var id: String { entry.keyPath }
}

// MARK: - Dashboard Data Helpers

/// Pure-logic helpers used by both the view and unit tests.
enum DashboardDataHelpers {

    /// Counts the total number of config files across all scopes in a scan result.
    static func totalFileCount(scanResult: ScanResult?) -> Int {
        guard let scan = scanResult else { return 0 }
        var count = 0
        // Managed files
        let mr = scan.managedResult
        if mr.settingsFile != nil { count += 1 }
        count += mr.settingsOverrideFiles.count
        if mr.mcpFile != nil { count += 1 }
        if mr.claudeMdFile != nil { count += 1 }
        // Managed workspace
        count += scan.managedWorkspace?.files.count ?? 0
        // User workspace
        count += scan.userWorkspace?.files.count ?? 0
        // Project workspaces
        count += scan.projectWorkspaces.reduce(0) { $0 + $1.files.count }
        return count
    }

    /// Counts config files for each scope, keyed by ResolutionScope.
    static func fileCounts(scanResult: ScanResult?) -> [ResolutionScope: Int] {
        guard let scan = scanResult else { return [:] }
        var result: [ResolutionScope: Int] = [:]

        // Managed
        var managedCount = 0
        let mr = scan.managedResult
        if mr.settingsFile != nil { managedCount += 1 }
        managedCount += mr.settingsOverrideFiles.count
        if mr.mcpFile != nil { managedCount += 1 }
        if mr.claudeMdFile != nil { managedCount += 1 }
        managedCount += scan.managedWorkspace?.files.count ?? 0
        result[.managed] = managedCount

        // User
        result[.user] = scan.userWorkspace?.files.count ?? 0

        // Project (combine all project workspaces by scopeKind)
        let projectCount = scan.projectWorkspaces
            .filter { $0.scope.scopeKind == .project }
            .reduce(0) { $0 + $1.files.count }
        result[.project] = projectCount

        return result
    }

    /// Issues per scope, derived from parse results.
    static func issueCounts(parseResults: [ParseResultRecord]) -> [ResolutionScope: Int] {
        var result: [ResolutionScope: Int] = [:]
        for record in parseResults {
            let count = record.parseIssues.count
            if count > 0 {
                result[record.scope, default: 0] += count
            }
        }
        return result
    }

    /// Selects the top N most-contested settings (most scopes with opinions).
    /// "Scopes with opinions" = trace.participants.count + trace.overridden.count
    static func recentConflicts(
        from projection: SessionProjection?,
        limit: Int = 5
    ) -> [ResolvedSettingsEntry] {
        guard let settings = projection?.settings else { return [] }
        return settings.entries
            .map { entry -> (ResolvedSettingsEntry, Int) in
                let count = entry.value.trace.participants.count
                    + entry.value.trace.overridden.count
                return (entry, count)
            }
            .filter { $0.1 > 1 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    /// Counts inaccessible/unreadable files from discovery issues.
    static func inaccessibleFileCount(scanResult: ScanResult?) -> Int {
        guard let scan = scanResult else { return 0 }
        let inaccessibleCodes: Set<DiscoveryIssueCode> = [
            .managedSettingsFileUnreadable,
            .managedSettingsDropInInaccessible,
            .scanDescendantInaccessible,
            .defaultRootInaccessible,
            .globalOverrideInaccessible,
            .projectInaccessible
        ]
        return scan.issues.filter { inaccessibleCodes.contains($0.code) }.count
    }
}

// MARK: - Dashboard View

@MainActor
struct ConfigurationDashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var pipeline: ConfigurationPipeline

    @State private var selectedTraceEntry: IdentifiableSettingsEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                healthSummaryCard
                scopeStackSection
                recentConflictsSection
                fileDiscoverySummarySection
                quickLinkGridSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.refreshPipeline()
                } label: {
                    if pipeline.pipelineState == .running {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(pipeline.pipelineState == .running)
            }
        }
        .sheet(item: $selectedTraceEntry) { wrapper in
            ResolutionTracePanelView(entry: wrapper.entry, onClose: { selectedTraceEntry = nil })
                .padding()
        }
    }

    // MARK: - Health Summary Card

    private var healthSummaryCard: some View {
        let issueSummary = pipeline.projection?.issueSummary
        let errorCount = issueSummary?.errorCount ?? 0
        let warningCount = issueSummary?.warningCount ?? 0
        let settingsCount = pipeline.projection?.settings?.entries.count ?? 0
        let activeScopes = activeScopeCount
        let isHealthy = errorCount == 0 && warningCount == 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuration Health")
                        .font(.headline)
                    if isHealthy && pipeline.projection != nil {
                        Label("Configuration looks healthy", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }
                Spacer()
                if isHealthy && pipeline.projection != nil {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                } else if pipeline.projection == nil {
                    Image(systemName: "questionmark.circle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 24) {
                statItem(label: "Active Scopes", value: "\(activeScopes)", icon: "square.stack.3d.up", color: .accentColor)
                statItem(label: "Resolved Settings", value: "\(settingsCount)", icon: "slider.horizontal.3", color: .blue)
                if warningCount > 0 {
                    statItem(label: "Warnings", value: "\(warningCount)", icon: "exclamationmark.triangle.fill", color: .orange)
                }
                if errorCount > 0 {
                    statItem(label: "Errors", value: "\(errorCount)", icon: "xmark.circle.fill", color: .red)
                }
                if warningCount == 0 && errorCount == 0 {
                    statItem(label: "Issues", value: "None", icon: "checkmark.circle.fill", color: .green)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title2.weight(.semibold))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var activeScopeCount: Int {
        guard let scan = pipeline.scanResult else { return 0 }
        var count = 0
        let mr = scan.managedResult
        let hasManagedFiles = mr.settingsFile != nil
            || !mr.settingsOverrideFiles.isEmpty
            || mr.mcpFile != nil
            || mr.claudeMdFile != nil
            || mr.mdmResult != nil
            || !(scan.managedWorkspace?.files.isEmpty ?? true)
        if hasManagedFiles { count += 1 }
        if !(scan.userWorkspace?.files.isEmpty ?? true) { count += 1 }
        let hasProject = scan.projectWorkspaces.contains { !$0.files.isEmpty }
        if hasProject { count += 1 }
        return count
    }

    // MARK: - Scope Stack

    private var scopeStackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scope Overview")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    scopeIndicator(.managed, label: "Managed")
                    scopeArrow
                    scopeIndicator(.user, label: "User")
                    scopeArrow
                    scopeIndicator(.project, label: "Project")
                    scopeArrow
                    scopeIndicator(.projectLocal, label: "Project-Local")
                    scopeArrow
                    scopeIndicator(.session, label: "Session")
                    scopeArrow
                    scopeIndicator(.cli, label: "CLI")
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var scopeArrow: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func scopeIndicator(_ scope: ResolutionScope, label: String) -> some View {
        let fileCounts = DashboardDataHelpers.fileCounts(scanResult: pipeline.scanResult)
        let issueCounts = DashboardDataHelpers.issueCounts(parseResults: pipeline.parseResults)
        let fileCount = fileCounts[scope] ?? 0
        let issueCount = issueCounts[scope] ?? 0
        let isActive = fileCount > 0

        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: scopeIcon(scope))
                    .font(.title3)
                    .foregroundStyle(isActive ? ScopeColorScheme.color(for: scope) : .secondary)
                    .frame(width: 32, height: 32)
                if issueCount > 0 {
                    Text("\(issueCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(.red, in: Capsule())
                        .offset(x: 8, y: -6)
                }
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isActive ? .primary : .secondary)
            if fileCount > 0 {
                Text("\(fileCount) file\(fileCount == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            } else {
                Text("inactive")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .opacity(isActive ? 1.0 : 0.5)
        .frame(minWidth: 62)
    }

    private func scopeIcon(_ scope: ResolutionScope) -> String {
        switch scope {
        case .managed: "building.2.crop.circle"
        case .user: "person.crop.circle"
        case .project: "folder"
        case .projectLocal: "folder.badge.gearshape"
        case .session: "sparkles.rectangle.stack"
        case .cli: "terminal"
        default: "circle"
        }
    }

    // MARK: - Recent Conflicts

    private var recentConflictsSection: some View {
        let conflicts = DashboardDataHelpers.recentConflicts(from: pipeline.projection)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Conflicts")
                    .font(.headline)
                Spacer()
                Text("Most-contested settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if conflicts.isEmpty {
                Text(pipeline.projection == nil
                     ? "Run the pipeline to see conflict data."
                     : "No contested settings found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(conflicts.enumerated()), id: \.element.keyPath) { _, entry in
                        conflictRow(entry: entry)
                        if entry.keyPath != conflicts.last?.keyPath {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.15))
                )
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func conflictRow(entry: ResolvedSettingsEntry) -> some View {
        let opinionCount = entry.value.trace.participants.count + entry.value.trace.overridden.count
        let valueString: String = {
            if let val = entry.value.effectiveValue {
                return DashboardDataHelpers.formatValue(val)
            }
            return "—"
        }()

        return Button {
            selectedTraceEntry = IdentifiableSettingsEntry(entry: entry)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.keyPath)
                        .font(.callout.monospaced().weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(valueString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(opinionCount) scopes")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                    if let scope = entry.value.winningSource?.scope {
                        ScopeColorScheme.scopeBadge(for: scope)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Discovery Summary

    private var fileDiscoverySummarySection: some View {
        let total = DashboardDataHelpers.totalFileCount(scanResult: pipeline.scanResult)
        let scopeCount = activeScopeCount
        let inaccessible = DashboardDataHelpers.inaccessibleFileCount(scanResult: pipeline.scanResult)

        return VStack(alignment: .leading, spacing: 8) {
            Text("File Discovery")
                .font(.headline)
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(Color.accentColor)
                Text("\(total) config file\(total == 1 ? "" : "s") found across \(scopeCount) scope\(scopeCount == 1 ? "" : "s")")
                    .font(.subheadline)
            }
            if inaccessible > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(inaccessible) file\(inaccessible == 1 ? "" : "s") could not be read")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            if pipeline.scanResult == nil {
                Text("No scan result yet — select a Claude folder to begin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Quick-Link Grid

    private var quickLinkGridSection: some View {
        let serverCount = pipeline.projection?.mcp?.servers.count ?? 0
        let hookCount = pipeline.projection?.hooks?.events.count ?? 0
        let issueCount = pipeline.semanticIssues.count
        let permissionKeyCount: Int = {
            guard let entries = pipeline.projection?.settings?.entries else { return 0 }
            return entries.filter { isPermissionKey($0.keyPath) }.count
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Quick Links")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quickLinkCard(
                    title: "Permissions",
                    count: permissionKeyCount,
                    icon: "shield.lefthalf.filled",
                    color: .purple,
                    destination: .tree
                )
                quickLinkCard(
                    title: "MCP Servers",
                    count: serverCount,
                    icon: "server.rack",
                    color: .teal,
                    destination: .session
                )
                quickLinkCard(
                    title: "Hooks",
                    count: hookCount,
                    icon: "arrow.triangle.pull",
                    color: .indigo,
                    destination: .session
                )
                quickLinkCard(
                    title: "Issues",
                    count: issueCount,
                    icon: "exclamationmark.triangle.fill",
                    color: issueCount > 0 ? .orange : .secondary,
                    destination: .issues
                )
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func quickLinkCard(
        title: String,
        count: Int,
        icon: String,
        color: Color,
        destination: SidebarDestination
    ) -> some View {
        Button {
            router.sidebarState.selection = destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func isPermissionKey(_ keyPath: String) -> Bool {
        let lower = keyPath.lowercased()
        return lower.contains("permission") || lower.contains("allow") || lower.contains("deny")
            || lower.contains("disable") || lower.contains("enable")
    }
}

extension DashboardDataHelpers {
    static func formatValue(_ value: JSONValue) -> String {
        switch value {
        case .string(let s):
            let truncated = s.count > 40 ? String(s.prefix(40)) + "…" : s
            return "\"\(truncated)\""
        case .bool(let b):
            return b ? "true" : "false"
        case .number(let n):
            return String(format: "%g", n)
        case .array(let items):
            return "[\(items.count) items]"
        case .object(let dict):
            return "{\(dict.count) keys}"
        case .null:
            return "null"
        }
    }
}
