import Foundation
import SwiftUI
import Combine

// MARK: - Display Models

/// A display-ready row for the conflict summary list.
struct ResolutionEntryDisplay: Identifiable {
    let id: String
    let keyPath: String
    let effectiveValueString: String
    let winningScope: ResolutionScope?
    let winningSourcePath: String?
    let mergeMethod: MergeMethod
    let mergeMethodLabel: String
    let overriddenCount: Int
    let participantCount: Int
    let waterfallNodes: [WaterfallNode]
    let hasConflict: Bool
    let isMergedArray: Bool
}

// MARK: - Filter Mode

/// Filter options for the conflict summary list.
enum ResolutionFilterMode: String, CaseIterable, Identifiable {
    case all = "All settings"
    case conflictsOnly = "Conflicts only"
    case mergedArrays = "Merged arrays"

    var id: String { rawValue }
}

// MARK: - View Model

/// Transforms `ResolvedSettingsSnapshot` entries into a sorted, filterable list
/// of display models for the resolution stage view.
@MainActor
final class TreeResolutionViewModel: ObservableObject {

    @Published private(set) var entries: [ResolutionEntryDisplay] = []
    @Published var filterMode: ResolutionFilterMode = .all
    @Published var searchText: String = ""

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?

    // MARK: - Binding

    func bind(to pipeline: ConfigurationPipeline) {
        self.pipeline = pipeline
        cancellables.removeAll()

        pipeline.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuild()
                }
            }
            .store(in: &cancellables)

        rebuild()
    }

    // MARK: - Filtered Results

    var filteredEntries: [ResolutionEntryDisplay] {
        var result = entries

        // Apply filter mode
        switch filterMode {
        case .all:
            break
        case .conflictsOnly:
            result = result.filter { $0.hasConflict }
        case .mergedArrays:
            result = result.filter { $0.isMergedArray }
        }

        // Apply search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.keyPath.lowercased().contains(query) }
        }

        return result
    }

    // MARK: - Stage Health

    var stageHealth: StageHealth {
        guard let settings = pipeline?.projection?.settings else { return .noData }

        var errorCount = 0
        var warningCount = 0

        for issue in settings.issues {
            switch issue.severity {
            case .error: errorCount += 1
            case .warning: warningCount += 1
            case .info: break
            }
        }

        if errorCount > 0 { return .errors(errorCount) }
        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }

    // MARK: - Private

    private func rebuild() {
        guard let settings = pipeline?.projection?.settings else {
            entries = []
            return
        }

        entries = settings.entries.map { entry in
            buildDisplay(from: entry)
        }
    }

    private func buildDisplay(from entry: ResolvedSettingsEntry) -> ResolutionEntryDisplay {
        let resolved = entry.value
        let effectiveString = jsonValueDisplayString(resolved.effectiveValue)
        let mergeLabel = Self.mergeMethodLabel(for: resolved.mergeMethod)

        let waterfallNodes = buildWaterfallNodes(from: resolved)

        let isMerged = [.append, .appendUnique, .setUnion, .deepMergeObject, .keyedByIdentifier]
            .contains(resolved.mergeMethod)

        return ResolutionEntryDisplay(
            id: entry.keyPath,
            keyPath: entry.keyPath,
            effectiveValueString: effectiveString,
            winningScope: resolved.winningSource?.scope,
            winningSourcePath: resolved.winningSource?.sourcePath,
            mergeMethod: resolved.mergeMethod,
            mergeMethodLabel: mergeLabel,
            overriddenCount: resolved.trace.overridden.count,
            participantCount: resolved.trace.participants.count,
            waterfallNodes: waterfallNodes,
            hasConflict: !resolved.trace.overridden.isEmpty,
            isMergedArray: isMerged && resolved.trace.participants.count > 1
        )
    }

    private func buildWaterfallNodes(from resolved: ResolvedValue<JSONValue>) -> [WaterfallNode] {
        // Canonical scope order for the waterfall: highest precedence first
        let scopeOrder: [ResolutionScope] = [
            .managed, .cli, .projectLocal, .project, .user, .session, .imported, .autoMemory, .synthetic
        ]

        let participantsByScope = Dictionary(
            grouping: resolved.trace.participants,
            by: { $0.scope }
        )
        let overriddenByScope = Dictionary(
            grouping: resolved.trace.overridden,
            by: { $0.scope }
        )
        let winnerScope = resolved.winningSource?.scope

        // Determine which scopes to show: only scopes that participated or were overridden
        let relevantScopes = scopeOrder.filter { scope in
            participantsByScope[scope] != nil || overriddenByScope[scope] != nil
        }

        // If no relevant scopes but we have a winner, show just the winner
        if relevantScopes.isEmpty, let winnerScope {
            return [
                WaterfallNode(
                    scope: winnerScope,
                    scopeLabel: winnerScope.rawValue.localizedCapitalized,
                    value: jsonValueDisplayString(resolved.effectiveValue),
                    status: .winner,
                    sourcePath: resolved.winningSource?.sourcePath
                )
            ]
        }

        let isMerge = [.append, .appendUnique, .setUnion, .deepMergeObject, .keyedByIdentifier]
            .contains(resolved.mergeMethod)

        return relevantScopes.map { scope in
            let isWinner = scope == winnerScope
            let isOverridden = overriddenByScope[scope] != nil
            let source = participantsByScope[scope]?.first ?? overriddenByScope[scope]?.first

            let status: WaterfallNodeStatus
            if isMerge && !isOverridden {
                status = isWinner ? .winner : .contributor
            } else if isWinner {
                status = .winner
            } else if isOverridden {
                status = .overridden
            } else {
                status = .absent
            }

            // For the value display, use the source path info
            let valueDisplay = source?.displayName ?? source?.identifier

            return WaterfallNode(
                scope: scope,
                scopeLabel: scope.rawValue.localizedCapitalized,
                value: valueDisplay,
                status: status,
                sourcePath: source?.sourcePath
            )
        }
    }

    // MARK: - Merge Method Labels

    static func mergeMethodLabel(for method: MergeMethod) -> String {
        switch method {
        case .selectHighestPrecedence:
            return "Highest precedence wins"
        case .replace:
            return "Full replacement"
        case .deepMergeObject:
            return "Deep merge (object)"
        case .append:
            return "Append (array concat)"
        case .appendUnique:
            return "Append unique values"
        case .setUnion:
            return "Set union"
        case .keyedByIdentifier:
            return "Keyed by identifier"
        case .passthrough:
            return "Passthrough"
        }
    }

    // MARK: - JSON Display

    private func jsonValueDisplayString(_ value: JSONValue?) -> String {
        guard let value else { return "[no value]" }
        return Self.formatJSONValue(value)
    }

    static func formatJSONValue(_ value: JSONValue, compact: Bool = true) -> String {
        switch value {
        case .string(let s):
            return compact ? "\"\(s)\"" : s
        case .number(let n):
            if n == n.rounded() && abs(n) < 1e15 {
                return String(format: "%.0f", n)
            }
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .null:
            return "null"
        case .array(let items):
            if compact && items.count > 3 {
                let first = items.prefix(3).map { formatJSONValue($0) }.joined(separator: ", ")
                return "[\(first), … +\(items.count - 3)]"
            }
            let inner = items.map { formatJSONValue($0) }.joined(separator: ", ")
            return "[\(inner)]"
        case .object(let dict):
            if compact && dict.count > 3 {
                let first = dict.keys.sorted().prefix(3).joined(separator: ", ")
                return "{\(first), … +\(dict.count - 3)}"
            }
            let inner = dict.keys.sorted()
                .map { "\($0): \(formatJSONValue(dict[$0]!))" }
                .joined(separator: ", ")
            return "{\(inner)}"
        }
    }
}
