import Foundation
import SwiftUI
import Combine

// MARK: - Display Models

/// Summary statistics for a single parsed file card.
struct ParsedFileSummary: Identifiable {
    let id: String
    let record: ParseResultRecord
    let recognizedKeyCount: Int
    let unknownKeyCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int

    /// All recognized top-level keys from the parsed JSON content.
    let recognizedKeys: [String]

    /// Unknown top-level keys (not in `SettingsKeyRegistry`).
    let unknownKeys: [String]

    /// Scope ordering weight (lower = earlier in display).
    let scopeOrder: Int

    /// Human-readable summary line, e.g. "14 keys recognized, 2 unknown, 1 error".
    var summaryLine: String {
        var parts: [String] = []
        if recognizedKeyCount > 0 {
            parts.append("\(recognizedKeyCount) key\(recognizedKeyCount == 1 ? "" : "s") recognized")
        }
        if unknownKeyCount > 0 {
            parts.append("\(unknownKeyCount) unknown")
        }
        if errorCount > 0 {
            parts.append("\(errorCount) error\(errorCount == 1 ? "" : "s")")
        }
        if warningCount > 0 {
            parts.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            return "No keys parsed"
        }
        return parts.joined(separator: ", ")
    }

    /// Overall parse health for this file.
    var health: StageHealth {
        if errorCount > 0 { return .errors(errorCount) }
        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }
}

// MARK: - View Model

/// Transforms `[ParseResultRecord]` from the pipeline into display-ready
/// file card summaries, sorted by scope order.
@MainActor
final class TreeParsingViewModel: ObservableObject {

    // MARK: - Published State

    /// Sorted file summaries, one per parsed file.
    @Published private(set) var fileSummaries: [ParsedFileSummary] = []

    /// Aggregate stage health across all parsed files.
    @Published private(set) var stageHealth: StageHealth = .noData

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?

    // MARK: - Binding

    /// Binds to the pipeline and recomputes whenever parse results change.
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

    // MARK: - Public Helpers

    /// Returns the `ParsedFileSummary` for a given file URL.
    func summary(for fileURL: URL) -> ParsedFileSummary? {
        fileSummaries.first(where: { $0.record.sourceFile == fileURL })
    }

    /// Returns the `ParseResultRecord` for a given file URL.
    func parseRecord(for fileURL: URL) -> ParseResultRecord? {
        pipeline?.parseResults.first(where: { $0.sourceFile == fileURL })
    }

    // MARK: - Private

    private func rebuild() {
        let records = pipeline?.parseResults ?? []
        guard !records.isEmpty else {
            fileSummaries = []
            stageHealth = .noData
            return
        }

        fileSummaries = records.map { buildSummary(from: $0) }
            .sorted { $0.scopeOrder < $1.scopeOrder }

        stageHealth = computeAggregateHealth()
    }

    private func buildSummary(from record: ParseResultRecord) -> ParsedFileSummary {
        // Count issues by severity
        var errorCount = 0
        var warningCount = 0
        var infoCount = 0
        for issue in record.parseIssues {
            switch issue.severity {
            case .error: errorCount += 1
            case .warning: warningCount += 1
            case .info: infoCount += 1
            }
        }

        // Extract keys from raw JSON content
        var allKeys: [String] = []
        if case .object(let dict) = record.rawContent {
            allKeys = dict.keys.sorted()
        }

        // Classify keys as recognized or unknown using the registry
        var recognizedKeys: [String] = []
        var unknownKeys: [String] = []

        if record.fileType == .settings {
            let registry = SettingsKeyRegistry.shared
            for key in allKeys {
                if registry.isKnownTopLevelKey(key) {
                    recognizedKeys.append(key)
                } else {
                    unknownKeys.append(key)
                }
            }
        } else {
            // For non-settings files, all keys are considered "recognized"
            recognizedKeys = allKeys
        }

        return ParsedFileSummary(
            id: record.id,
            record: record,
            recognizedKeyCount: recognizedKeys.count,
            unknownKeyCount: unknownKeys.count,
            errorCount: errorCount,
            warningCount: warningCount,
            infoCount: infoCount,
            recognizedKeys: recognizedKeys,
            unknownKeys: unknownKeys,
            scopeOrder: scopeOrder(for: record.scope)
        )
    }

    private func scopeOrder(for scope: ResolutionScope) -> Int {
        switch scope {
        case .managed: return 0
        case .user: return 1
        case .project: return 2
        case .projectLocal: return 3
        case .session: return 4
        case .cli: return 5
        case .imported: return 6
        case .autoMemory: return 7
        case .synthetic: return 8
        }
    }

    private func computeAggregateHealth() -> StageHealth {
        var totalErrors = 0
        var totalWarnings = 0

        for summary in fileSummaries {
            totalErrors += summary.errorCount
            totalWarnings += summary.warningCount
        }

        if totalErrors > 0 { return .errors(totalErrors) }
        if totalWarnings > 0 { return .warnings(totalWarnings) }
        return fileSummaries.isEmpty ? .noData : .healthy
    }
}
