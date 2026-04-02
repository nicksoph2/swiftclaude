import SwiftUI

/// View A: The Config Grid.
///
/// Rows are settings keys grouped by user intent (Model & Reasoning, Safety & Permissions, etc.).
/// Columns are scopes (Managed, User, Project, …) plus a Resolved column.
/// Each cell shows the actual value with winner/overridden/contributor colouring.
/// Click any row to expand and see merge method, resolution trace, and full values.
struct ConfigGridView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = ConfigGridViewModel()
    @State private var collapsedGroups: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            gridContent
        }
        .onAppear {
            Task { @MainActor in
                viewModel.bind(to: pipeline)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "tablecells")
                .foregroundStyle(.secondary)
            Text("Config Grid")
                .font(.headline)

            Spacer()

            // Filter picker
            Picker("Filter", selection: $viewModel.filterMode) {
                ForEach(ConfigGridViewModel.FilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("Search keys…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Grid content

    private var gridContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Column headers
                columnHeader

                // Grouped rows
                ForEach(viewModel.groupedRows) { section in
                    sectionView(section)
                }

                if viewModel.groupedRows.isEmpty {
                    emptyState
                }
            }
        }
    }

    // MARK: - Column header

    private var columnHeader: some View {
        HStack(spacing: 0) {
            // Key column
            Text("Setting")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            // Scope columns
            ForEach(viewModel.activeScopes, id: \.self) { scope in
                HStack(spacing: 4) {
                    Circle()
                        .fill(ScopeColorScheme.color(for: scope))
                        .frame(width: 6, height: 6)
                    Text(scope.rawValue.localizedCapitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Resolved column
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                Text("Resolved")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.04))
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Section

    private func sectionView(_ section: ConfigGridSection) -> some View {
        Section {
            if !isCollapsed(section.group) {
                ForEach(section.rows) { row in
                    VStack(spacing: 0) {
                        rowView(row)
                        if viewModel.isExpanded(row.id) {
                            detailPanel(row)
                        }
                    }
                }
            }
        } header: {
            sectionHeader(section)
        }
    }

    private func sectionHeader(_ section: ConfigGridSection) -> some View {
        Button {
            toggleCollapsed(section.group)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed(section.group) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                Image(systemName: section.group.systemImage)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)

                Text(section.group.title)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.orange)

                Text(section.group.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(section.totalCount) keys")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                if section.conflictCount > 0 {
                    Text("\(section.conflictCount) conflict\(section.conflictCount == 1 ? "" : "s")")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar.opacity(0.8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Row

    private func rowView(_ row: ConfigGridRow) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleExpanded(row.id)
            }
        } label: {
            HStack(spacing: 0) {
                // Key column
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.keyPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(row.typeLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        if let scope = row.originScope {
                            OriginBreadcrumbView(sourcePath: row.originPath, scope: scope)
                        }
                    }
                }
                .frame(width: 190, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                // Scope cells
                ForEach(row.scopeCells) { cell in
                    ValueCellView(cell.displayValue, status: cell.status)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }

                // Resolved cell
                resolvedCell(row)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.02))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(viewModel.isExpanded(row.id) ? Color.orange.opacity(0.03) : .clear)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    @ViewBuilder
    private func resolvedCell(_ row: ConfigGridRow) -> some View {
        if let value = row.resolvedValue.effectiveValue {
            let displayText = formatResolvedValue(value, mergeMethod: row.mergeMethod)
            ValueCellView(displayText, status: .winner)
        } else {
            ValueCellView("—", status: .absent)
        }
    }

    private func formatResolvedValue(_ value: JSONValue, mergeMethod: MergeMethod) -> String {
        switch value {
        case .string(let s): return s
        case .bool(let b): return b ? "true" : "false"
        case .number(let n):
            return n == n.rounded() && n < 1_000_000 ? String(Int(n)) : String(format: "%.2f", n)
        case .null: return "null"
        case .array(let arr):
            let symbol = (mergeMethod == .appendUnique || mergeMethod == .setUnion) ? " ⊕" : ""
            return "\(arr.count) items\(symbol)"
        case .object(let obj):
            return "{\(obj.count) keys}"
        }
    }

    // MARK: - Detail panel

    private func detailPanel(_ row: ConfigGridRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Merge method
            HStack(spacing: 6) {
                Text("Merge:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(row.mergeMethod.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            // Description
            if !row.description.isEmpty {
                Text(row.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Resolution trace: who participated, who was overridden
            if !row.resolvedValue.trace.participants.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resolution trace:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(row.resolvedValue.trace.participants, id: \.id) { source in
                        let isOverridden = row.resolvedValue.trace.overridden.contains(source)
                        let isWinner = row.resolvedValue.winningSource == source
                        HStack(spacing: 6) {
                            ScopeChipView(
                                scope: source.scope,
                                label: source.displayName ?? source.identifier,
                                status: isWinner ? .winner : (isOverridden ? .overridden : .contributor)
                            )
                            if let path = source.sourcePath {
                                Text(path)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            // Notes from resolution
            ForEach(Array(row.notes.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Validation issues
            ForEach(row.issues, id: \.id) { issue in
                HStack(spacing: 4) {
                    Image(systemName: issue.severity == .error ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .font(.system(size: 9))
                        .foregroundStyle(issue.severity == .error ? .red : .yellow)
                    Text(issue.message)
                        .font(.system(size: 10))
                        .foregroundStyle(issue.severity == .error ? .red : .yellow)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .padding(.leading, 190)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No settings to display")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if viewModel.filterMode != .all || !viewModel.searchText.isEmpty {
                Text("Try changing the filter or clearing the search")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Collapse management

    private func isCollapsed(_ group: FunctionalGroup) -> Bool {
        collapsedGroups.contains(group.rawValue)
    }

    private func toggleCollapsed(_ group: FunctionalGroup) {
        if collapsedGroups.contains(group.rawValue) {
            collapsedGroups.remove(group.rawValue)
        } else {
            collapsedGroups.insert(group.rawValue)
        }
    }
}
