import SwiftUI
import Combine

/// View model for the Config Grid (View A).
///
/// Reads `SessionProjection` and transforms resolved settings entries into
/// functional groups of rows, each showing per-scope values and resolution status.
@MainActor
final class ConfigGridViewModel: ObservableObject {

    // MARK: - Published state

    @Published var groupedRows: [ConfigGridSection] = []
    @Published var activeScopes: [ResolutionScope] = []
    @Published var searchText: String = ""
    @Published var filterMode: FilterMode = .all
    @Published var expandedRowIDs: Set<String> = []

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case conflictsOnly = "Conflicts"
        case sharedOnly = "Shared"
        case definedInMultiple = "Multi-Scope"
    }

    // MARK: - Pipeline binding

    private weak var pipeline: ConfigurationPipeline?
    private var cancellables = Set<AnyCancellable>()

    func bind(to pipeline: ConfigurationPipeline) {
        self.pipeline = pipeline
        pipeline.$projection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projection in
                self?.rebuild(from: projection)
            }
            .store(in: &cancellables)
    }

    // MARK: - Row toggling

    func toggleExpanded(_ rowID: String) {
        if expandedRowIDs.contains(rowID) {
            expandedRowIDs.remove(rowID)
        } else {
            expandedRowIDs.insert(rowID)
        }
    }

    func isExpanded(_ rowID: String) -> Bool {
        expandedRowIDs.contains(rowID)
    }

    // MARK: - Rebuild

    private func rebuild(from projection: SessionProjection?) {
        guard let projection else {
            groupedRows = []
            activeScopes = []
            return
        }

        // Determine which scopes have any data
        let scopeSet = discoverActiveScopes(from: projection)
        activeScopes = scopeSet.sorted { scopePrecedence($0) < scopePrecedence($1) }

        // Build rows from resolved settings entries
        let registry = SettingsKeyRegistry.shared
        var rows: [ConfigGridRow] = []

        if let settings = projection.settings {
            for entry in settings.entries {
                let definition = registry.definition(for: entry.keyPath)
                let group = definition.map { FunctionalGroup.group(for: $0) } ?? .general

                let scopeCells = buildScopeCells(
                    for: entry,
                    activeScopes: activeScopes
                )

                let row = ConfigGridRow(
                    id: entry.keyPath,
                    keyPath: entry.keyPath,
                    typeLabel: definition?.type.displayName ?? "value",
                    group: group,
                    scopeCells: scopeCells,
                    resolvedValue: entry.value,
                    mergeMethod: entry.value.mergeMethod,
                    originPath: entry.value.winningSource?.sourcePath,
                    originScope: entry.value.winningSource?.scope,
                    description: definition?.description ?? "",
                    isManagedOnly: definition?.isManagedOnly ?? false,
                    hasConflict: entry.value.trace.overridden.count > 0,
                    isDefinedInMultipleScopes: entry.value.trace.participants.count > 1,
                    isSharedValue: scopeCells.filter({ $0.status != .absent }).count > 1
                        && entry.value.trace.overridden.isEmpty,
                    issues: entry.value.issues,
                    notes: entry.value.notes
                )
                rows.append(row)
            }
        }

        // Group by functional group
        let grouped = Dictionary(grouping: rows) { $0.group }
        groupedRows = FunctionalGroup.allCases.compactMap { group in
            let sectionRows = grouped[group] ?? []
            guard !sectionRows.isEmpty else { return nil }

            let conflictCount = sectionRows.filter(\.hasConflict).count
            return ConfigGridSection(
                group: group,
                rows: applyFilter(sectionRows),
                totalCount: sectionRows.count,
                conflictCount: conflictCount
            )
        }
    }

    private func applyFilter(_ rows: [ConfigGridRow]) -> [ConfigGridRow] {
        var filtered = rows

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { row in
                row.keyPath.lowercased().contains(query)
                || row.description.lowercased().contains(query)
                || row.group.title.lowercased().contains(query)
            }
        }

        // Apply filter mode
        switch filterMode {
        case .all:
            break
        case .conflictsOnly:
            filtered = filtered.filter(\.hasConflict)
        case .sharedOnly:
            filtered = filtered.filter(\.isSharedValue)
        case .definedInMultiple:
            filtered = filtered.filter(\.isDefinedInMultipleScopes)
        }

        return filtered
    }

    // MARK: - Scope cell building

    private func buildScopeCells(
        for entry: ResolvedSettingsEntry,
        activeScopes: [ResolutionScope]
    ) -> [ConfigGridScopeCell] {
        activeScopes.map { scope in
            let participant = entry.value.trace.participants.first { $0.scope == scope }
            let isOverridden = entry.value.trace.overridden.contains { $0.scope == scope }
            let isWinner = entry.value.winningSource?.scope == scope

            if participant != nil {
                let displayValue = extractScopeValue(
                    for: entry.keyPath,
                    scope: scope,
                    from: entry.value
                )

                let status: ValueCellView.CellStatus
                if isWinner {
                    status = .winner
                } else if isOverridden {
                    status = .overridden
                } else {
                    // Contributor (e.g. append-merged arrays)
                    status = .contributor
                }

                return ConfigGridScopeCell(
                    scope: scope,
                    displayValue: displayValue,
                    status: status,
                    sourcePath: participant?.sourcePath
                )
            } else {
                return ConfigGridScopeCell(
                    scope: scope,
                    displayValue: "—",
                    status: .absent,
                    sourcePath: nil
                )
            }
        }
    }

    private func extractScopeValue(
        for keyPath: String,
        scope: ResolutionScope,
        from resolved: ResolvedValue<JSONValue>
    ) -> String {
        // For the winning scope, show the effective value
        if resolved.winningSource?.scope == scope {
            return formatJSONValue(resolved.effectiveValue)
        }

        // For overridden/contributor scopes, show what they contributed
        // We know they participated, so show a scope indicator
        // Full detail is available in the expanded row
        return formatJSONValue(resolved.effectiveValue) + " ⟵"
    }

    private func formatJSONValue(_ value: JSONValue?) -> String {
        guard let value else { return "null" }
        switch value {
        case .string(let s):
            return s
        case .number(let n):
            if n == n.rounded() && n < 1_000_000 {
                return String(Int(n))
            }
            return String(format: "%.2f", n)
        case .bool(let b):
            return b ? "true" : "false"
        case .null:
            return "null"
        case .array(let arr):
            if arr.count <= 3 {
                return "[\(arr.map { formatJSONValue($0) }.joined(separator: ", "))]"
            }
            return "[\(arr.count) items]"
        case .object(let obj):
            return "{\(obj.count) keys}"
        }
    }

    // MARK: - Scope discovery

    private func discoverActiveScopes(from projection: SessionProjection) -> Set<ResolutionScope> {
        var scopes = Set<ResolutionScope>()
        if let settings = projection.settings {
            for entry in settings.entries {
                for participant in entry.value.trace.participants {
                    scopes.insert(participant.scope)
                }
            }
        }
        return scopes
    }

    private func scopePrecedence(_ scope: ResolutionScope) -> Int {
        switch scope {
        case .managed:      0
        case .user:         1
        case .project:      2
        case .projectLocal: 3
        case .session:      4
        case .cli:          5
        case .imported:     6
        case .autoMemory:   7
        case .synthetic:    8
        }
    }
}

// MARK: - Data models

struct ConfigGridSection: Identifiable {
    let group: FunctionalGroup
    let rows: [ConfigGridRow]
    let totalCount: Int
    let conflictCount: Int

    var id: String { group.rawValue }
}

struct ConfigGridRow: Identifiable {
    let id: String
    let keyPath: String
    let typeLabel: String
    let group: FunctionalGroup
    let scopeCells: [ConfigGridScopeCell]
    let resolvedValue: ResolvedValue<JSONValue>
    let mergeMethod: MergeMethod
    let originPath: String?
    let originScope: ResolutionScope?
    let description: String
    let isManagedOnly: Bool
    let hasConflict: Bool
    let isDefinedInMultipleScopes: Bool
    let isSharedValue: Bool
    let issues: [ResolutionIssue]
    let notes: [String]
}

struct ConfigGridScopeCell: Identifiable {
    let scope: ResolutionScope
    let displayValue: String
    let status: ValueCellView.CellStatus
    let sourcePath: String?

    var id: String { scope.rawValue }
}
