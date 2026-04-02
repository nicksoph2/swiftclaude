import SwiftUI

/// Stage 3 — Resolution detail view.
///
/// Two sub-views:
/// - **Sub-view A: Conflict Summary List** — filterable, searchable list of all resolved
///   settings entries with key path, effective value, winning source badge, merge method,
///   and conflict indicator.
/// - **Sub-view B: Resolution Waterfall** — drill-down showing the full scope tier waterfall
///   for a selected key.
/// - **Sub-view Z5: Sub-process expansion** — three merge-method lanes shown when the
///   "Show sub-processes" toggle is active.
struct TreeResolutionView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeResolutionViewModel()

    @State private var selectedEntry: ResolutionEntryDisplay?

    /// The resolved entry whose trace panel is currently shown.
    @State private var traceTarget: ResolvedSettingsEntry?

    @State private var showSettingsChangeImpact: Bool = false

    /// Persisted expansion state for the sub-process lane diagram (Z5).
    @SceneStorage("resolutionSubProcessExpanded") private var subProcessExpanded: Bool = false

    /// Persisted "show conflicts only" filter state.
    @SceneStorage("showConflictsOnly") private var showConflictsOnly: Bool = false

    /// Optional cross-stage navigation callback.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StageExplanationView(stage: .resolution)
                Spacer()
                Button {
                    showSettingsChangeImpact = true
                } label: {
                    Label("Test a change", systemImage: "slider.horizontal.2.arrow.trianglehead.counterclockwise")
                        .font(.caption)
                }
                .help("Preview the impact of a hypothetical settings change")
            }
            .sheet(isPresented: $showSettingsChangeImpact) {
                SettingsChangeImpactView()
            }

            if viewModel.entries.isEmpty {
                noDataPlaceholder
            } else if let entry = selectedEntry {
                waterfallDrillDown(for: entry)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Sub-process toggle (Z5)
                    subProcessToggleButton

                    if subProcessExpanded {
                        ResolutionSubProcessView(entries: viewModel.entries)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: UnitPoint.top)))
                    }

                    conflictSummaryList
                }
                .animation(.easeInOut(duration: 0.2), value: subProcessExpanded)
            }
        }
        .onAppear {
            viewModel.bind(to: pipeline)
        }
        .sheet(isPresented: Binding(
            get: { traceTarget != nil },
            set: { if !$0 { traceTarget = nil } }
        )) {
            if let target = traceTarget {
                ResolutionTracePanelView(
                    entry: target,
                    onClose: { traceTarget = nil },
                    onNavigate: onNavigate
                )
            }
        }
    }

    // MARK: - Sub-process Toggle

    @ViewBuilder
    private var subProcessToggleButton: some View {
        Button {
            subProcessExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: subProcessExpanded
                      ? "chevron.down.circle.fill"
                      : "chevron.right.circle")
                    .font(.caption)
                Text(subProcessExpanded ? "Hide sub-processes" : "Show sub-processes")
                    .font(.callout.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
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

            // Merge method examples disclosure
            DisclosureGroup("Merge method examples", isExpanded: Binding(
                get: { viewModel.showMergeExamples },
                set: { viewModel.showMergeExamples = $0 }
            )) {
                MergeMethodExampleView()
                    .padding(.top, 8)
            }
            .font(.caption.weight(.medium))

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

            // Conflicts-only toolbar button
            Button {
                showConflictsOnly.toggle()
                viewModel.filterMode = showConflictsOnly ? .conflictsOnly : .all
            } label: {
                Image(systemName: showConflictsOnly
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.body)
                    .foregroundStyle(showConflictsOnly ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help("Show conflicts only")

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
        .onChange(of: viewModel.filterMode) { _, newMode in
            showConflictsOnly = (newMode == .conflictsOnly)
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
                    systemImage: "exclamationmark.circle.fill"
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

                // Merge method label with icon
                HStack(spacing: 3) {
                    Image(systemName: TreeResolutionViewModel.mergeMethodIcon(for: entry.mergeMethod))
                        .font(.caption2)
                    Text(entry.mergeMethodLabel)
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .help(entry.mergeMethod.rawValue)

                // Conflict badge
                if entry.hasConflict {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Resolved conflict — multiple scopes had different values for this key")
                }

                // Winning source scope badge
                if let scope = entry.winningScope {
                    ScopeColorScheme.scopeBadge(for: scope)
                }

                // Trace panel button
                Button {
                    traceTarget = entry.resolvedEntry
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show resolution trace")

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

            // Trace panel button
            if let resolvedEntry = entry.resolvedEntry {
                Button {
                    traceTarget = resolvedEntry
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Show resolution trace")
                            .font(.callout)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

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
