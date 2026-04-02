import Foundation
import SwiftUI
import Combine

// MARK: - Diagram Mode

/// Controls whether the pipeline diagram shows all eight stages (advanced)
/// or three composite "plain English" nodes (simplified).
enum DiagramMode: String, CaseIterable, Sendable {
    case simplified
    case advanced
}

// MARK: - Composite Stage Group

/// Three composite groups used in simplified mode.
enum CompositeStageGroup: String, CaseIterable, Identifiable, Sendable {
    case yourFiles      = "yourFiles"
    case theRules       = "theRules"
    case whatClaudeSees = "whatClaudeSees"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yourFiles:      "Your Files"
        case .theRules:       "The Rules"
        case .whatClaudeSees: "What Claude Sees"
        }
    }

    var icon: String {
        switch self {
        case .yourFiles:      "doc.on.doc"
        case .theRules:       "list.bullet.clipboard"
        case .whatClaudeSees: "cpu"
        }
    }

    var constituentStages: [PipelineStage] {
        switch self {
        case .yourFiles:      [.discovery, .parsing]
        case .theRules:       [.resolution, .toolExecution, .hooksLifecycle]
        case .whatClaudeSees: [.promptAssembly, .mcpServers, .contextBudget]
        }
    }
}

/// Coordinates stage health badges for the pipeline overview strip.
///
/// Observes `ConfigurationPipeline` and computes a `StageHealth` value
/// for each `PipelineStage` based on the current pipeline data.
@MainActor
final class TreePipelineViewModel: ObservableObject {

    /// Published snapshot of per-stage health, ordered by `PipelineStage.sortOrder`.
    @Published private(set) var stageHealthEntries: [(stage: PipelineStage, health: StageHealth)] = []

    /// The currently selected (zoomed-in) stage. `nil` means the full diagram is shown.
    @Published var selectedStage: PipelineStage? = nil

    private var cancellables = Set<AnyCancellable>()

    /// The pipeline whose published properties drive health computation.
    private weak var pipeline: ConfigurationPipeline?

    init() {
        // Initialize with noData for every stage
        stageHealthEntries = PipelineStage.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ($0, .noData) }
    }

    /// Binds to the given pipeline and starts observing its published state.
    func bind(to pipeline: ConfigurationPipeline) {
        self.pipeline = pipeline
        cancellables.removeAll()

        // Re-compute health whenever any pipeline output changes.
        pipeline.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Schedule update for next run loop so published values are available.
                DispatchQueue.main.async {
                    self?.recomputeHealth()
                }
            }
            .store(in: &cancellables)

        // Compute immediately for current state.
        recomputeHealth()
    }

    // MARK: - Public API

    /// Returns the health for a single stage.
    func stageHealth(for stage: PipelineStage) -> StageHealth {
        stageHealthEntries.first(where: { $0.stage == stage })?.health ?? .noData
    }

    // MARK: - Private

    private func recomputeHealth() {
        guard let pipeline else { return }

        stageHealthEntries = PipelineStage.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { stage in
                (stage, computeHealth(for: stage, pipeline: pipeline))
            }
    }

    private func computeHealth(for stage: PipelineStage, pipeline: ConfigurationPipeline) -> StageHealth {
        switch stage {
        case .discovery:
            return discoveryHealth(pipeline)
        case .parsing:
            return parsingHealth(pipeline)
        case .resolution:
            return resolutionHealth(pipeline)
        case .promptAssembly:
            return pipeline.projection?.instructions != nil ? .healthy : .noData
        case .toolExecution:
            return pipeline.projection?.settings != nil ? .healthy : .noData
        case .hooksLifecycle:
            return pipeline.projection?.hooks != nil ? .healthy : .noData
        case .mcpServers:
            return pipeline.projection?.mcp != nil ? .healthy : .noData
        case .contextBudget:
            return contextBudgetHealth(pipeline)
        }
    }

    // MARK: - Per-Stage Health Logic

    /// Discovery: inspects file statuses from `scanResult`.
    private func discoveryHealth(_ pipeline: ConfigurationPipeline) -> StageHealth {
        guard let scan = pipeline.scanResult else { return .noData }

        var errorCount = 0

        let allWorkspaces = [scan.managedWorkspace, scan.userWorkspace].compactMap { $0 }
            + scan.projectWorkspaces

        for workspace in allWorkspaces {
            for file in workspace.files {
                switch file.status {
                case .unreadable, .inaccessible, .unsupported:
                    errorCount += 1
                case .missing:
                    // Missing is expected for optional config files; treat as warning only
                    // if we want to be strict, but typically this is informational.
                    break
                case .present:
                    break
                }
            }
        }

        // Also count discovery-level issues
        errorCount += scan.issues.count

        if errorCount > 0 { return .errors(errorCount) }

        // At least one workspace must have been scanned
        let hasFiles = allWorkspaces.contains { !$0.files.isEmpty }
        return hasFiles ? .healthy : .noData
    }

    /// Parsing: inspects issue counts from `parseResults`.
    private func parsingHealth(_ pipeline: ConfigurationPipeline) -> StageHealth {
        let records = pipeline.parseResults
        guard !records.isEmpty else { return .noData }

        var errorCount = 0
        var warningCount = 0

        for record in records {
            for issue in record.parseIssues {
                switch issue.severity {
                case .error:
                    errorCount += 1
                case .warning:
                    warningCount += 1
                case .info:
                    break
                }
            }
        }

        if errorCount > 0 { return .errors(errorCount) }
        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }

    /// Resolution: inspects overridden/conflict counts from resolved settings.
    private func resolutionHealth(_ pipeline: ConfigurationPipeline) -> StageHealth {
        guard let settings = pipeline.projection?.settings else { return .noData }

        var errorCount = 0
        var warningCount = 0

        for issue in settings.issues {
            switch issue.severity {
            case .error:
                errorCount += 1
            case .warning:
                warningCount += 1
            case .info:
                break
            }
        }

        if errorCount > 0 { return .errors(errorCount) }
        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }

    /// Context Budget: green if overhead < 15%, amber if 15–30%, red if > 30%.
    private func contextBudgetHealth(_ pipeline: ConfigurationPipeline) -> StageHealth {
        guard let projection = pipeline.projection else { return .noData }

        // Compute total overhead the same way the ViewModel does
        var overhead = PromptLayerConstants.systemPromptTokens
            + PromptLayerConstants.toolDefinitionTokens
            + PromptLayerConstants.baselineOverhead

        if let instructions = projection.instructions,
           let composed = instructions.composedInstructions.effectiveValue {
            overhead += TokenEstimator.estimateTokenCount(composed)
        }

        if let instructions = projection.instructions {
            let topicCount = instructions.startupMemoryTopics.count
                + instructions.onDemandMemoryTopics.count
            overhead += topicCount * 200
        }

        let percentage = Double(overhead) / Double(PromptLayerConstants.contextWindowSize) * 100.0

        if percentage > 30 { return .errors(1) }
        if percentage > 15 { return .warnings(1) }
        return .healthy
    }

}
