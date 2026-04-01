import SwiftUI

/// Stage 3 — Resolution detail view.
///
/// Two sub-views:
/// - **Sub-view A: Conflict Summary List** — filterable, searchable list of all resolved
///   settings entries with key path, effective value, winning source badge, merge method,
///   and conflict indicator.
/// - **Sub-view B: Resolution Waterfall** — drill-down showing the full scope tier waterfall
///   for a selected key.
struct TreeResolutionView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeResolutionViewModel()

    @State private var selectedEntry: ResolutionEntryDisplay?

    /// Optional cross-stage navigation callback.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.entries.isEmpty {
                noDataPlaceholder
            } else if let entry = selectedEntry {
                waterfallDrillDown(for: entry)
            } else {
                conflictSummaryList
            }
        }
        .onAppear {
            viewModel.bind(to: pipeline)
        }
    }

    // MARK: - No Data

    @ViewBuilder
    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No resolved settings available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Run the configuration pipeline to see how settings resolve across scopes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Sub-view A: Conflict Summary List

    @ViewBuilder
    private var conflictSummaryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Filter controls
            filterBar

            // Summary counts
            summaryBanner

            // Entry list
            let filtered = viewModel.filteredEntries
            if filtered.isEmpty {
                Text("No settings match the current filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filtered) { entry in
                        entryRow(for: entry)
                            .id("resolution-\(entry.keyPath)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Filter picker
            Picker("Filter", selection: $viewModel.filterMode) {
                ForEach(ResolutionFilterMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Spacer()

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Filter by key path…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .frame(maxWidth: 240)
        }
    }

    @ViewBuilder
    private var summaryBanner: some View {
        let total = viewModel.entries.count
        let conflicts = viewModel.entries.filter(\.hasConflict).count
        let merged = viewModel.entries.filter(\.isMergedArray).count

        HStack(spacing: 16) {
            Label("\(total) settings", systemImage: "gearshape")
                .font(.caption)
                .foregroundStyle(.secondary)

            if conflicts > 0 {
                Label(
                    "\(conflicts) conflict\(conflicts == 1 ? "" : "s")",
                    systemImage: "arrow.triangle.branch"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if merged > 0 {
                Label(
                    "\(merged) merged",
                    systemImage: "arrow.triangle.merge"
                )
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(for entry: ResolutionEntryDisplay) -> some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 10) {
                // Key path
                Text(entry.keyPath)
                    .font(.callout.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // Merge method label
                Text(entry.mergeMethodLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Conflict indicator
                if entry.hasConflict {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                        Text("\(entry.overriddenCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                }

                // Winning source scope badge
                if let scope = entry.winningScope {
                    ScopeColorScheme.scopeBadge(for: scope)
                }

                // Effective value (truncated)
                Text(entry.effectiveValueString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sub-view B: Waterfall Drill-Down

    @ViewBuilder
    private func waterfallDrillDown(for entry: ResolutionEntryDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back button
            Button {
                selectedEntry = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                    Text("Back to summary")
                        .font(.callout)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            // Waterfall view
            ResolutionWaterfallView(
                keyPath: entry.keyPath,
                mergeMethodLabel: entry.mergeMethodLabel,
                mergeMethod: entry.mergeMethod,
                effectiveValue: entry.effectiveValueString,
                nodes: entry.waterfallNodes,
                onScopeTapped: { node in
                    // Stage 3 → Stage 2: Navigate to the source file's parse card in Parsing
                    if let path = node.sourcePath {
                        let url = URL(fileURLWithPath: path)
                        onNavigate?(.parsingFile(url))
                    }
                }
            )

            // Stage 3 → Stage 5: Cross-nav to Tool Execution for permission-related settings
            if isPermissionRelatedKey(entry.keyPath) {
                Button {
                    onNavigate?(.toolExecutionGate(.permissions))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                        Text("View in Tool Execution")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Jump to the Permission Rules gate in Stage 5 — Tool Execution")
            }
        }
    }

    // MARK: - Helpers

    /// Returns `true` when a resolved-settings key path relates to permission rules
    /// that are visualised in the Tool Execution permissions gate (Stage 5).
    private func isPermissionRelatedKey(_ keyPath: String) -> Bool {
        let lower = keyPath.lowercased()
        return lower.hasPrefix("permissions") || lower == "allow" || lower == "deny"
    }
}
