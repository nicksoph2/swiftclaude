import Foundation
import SwiftUI
import Combine

// MARK: - View Model

/// Transforms prompt assembly token estimates into a visual context budget breakdown.
///
/// Builds an array of `ContextBudgetSegment` items representing the proportional
/// allocation of the 200K context window, computing remaining conversation budget
/// and health based on overhead percentage.
@MainActor
final class TreeContextBudgetViewModel: ObservableObject {

    // MARK: - Published State

    /// Ordered segments for the stacked bar visualization.
    @Published private(set) var segments: [ContextBudgetSegment] = []

    /// Tokens remaining for conversation after all overhead is subtracted.
    @Published private(set) var remainingTokens: Int = 0

    /// Total overhead tokens consumed before conversation begins.
    @Published private(set) var totalOverheadTokens: Int = 0

    /// Overhead as a percentage of the full context window (0–100).
    @Published private(set) var overheadPercentage: Double = 0

    /// Aggregate stage health based on overhead percentage thresholds.
    @Published private(set) var stageHealth: StageHealth = .noData

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?

    // MARK: - Binding

    /// Binds to the pipeline and recomputes whenever projection changes.
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

    // MARK: - Private Rebuild

    private func rebuild() {
        guard let projection = pipeline?.projection else {
            segments = []
            remainingTokens = 0
            totalOverheadTokens = 0
            overheadPercentage = 0
            stageHealth = .noData
            return
        }

        let builtSegments = buildSegments(from: projection)
        segments = builtSegments

        let overhead = builtSegments.reduce(0) { $0 + $1.estimatedTokens }
        totalOverheadTokens = overhead
        remainingTokens = max(0, PromptLayerConstants.contextWindowSize - overhead)
        overheadPercentage = Double(overhead) / Double(PromptLayerConstants.contextWindowSize) * 100.0
        stageHealth = computeHealth()
    }

    // MARK: - Segment Building

    private func buildSegments(from projection: SessionProjection) -> [ContextBudgetSegment] {
        var result: [ContextBudgetSegment] = []

        // Segment 1: System Prompt (fixed)
        result.append(ContextBudgetSegment(
            id: "budget-system-prompt",
            layer: "System Prompt",
            estimatedTokens: PromptLayerConstants.systemPromptTokens,
            color: "gray"
        ))

        // Segment 2: Tool Definitions (fixed)
        result.append(ContextBudgetSegment(
            id: "budget-tool-definitions",
            layer: "Tool Definitions",
            estimatedTokens: PromptLayerConstants.toolDefinitionTokens,
            color: "purple"
        ))

        // Segment 3: CLAUDE.md Instructions (configurable, variable)
        let instructionTokens = estimateInstructionTokens(from: projection)
        result.append(ContextBudgetSegment(
            id: "budget-instructions",
            layer: "CLAUDE.md Instructions",
            estimatedTokens: instructionTokens,
            color: "green",
            isConfigurable: true
        ))

        // Segment 4: Auto-Memory (configurable, variable)
        let memoryTokens = estimateMemoryTokens(from: projection)
        result.append(ContextBudgetSegment(
            id: "budget-auto-memory",
            layer: "Auto-Memory",
            estimatedTokens: memoryTokens,
            color: "indigo",
            isConfigurable: true
        ))

        // Segment 5: Baseline Overhead (framework overhead not covered above)
        result.append(ContextBudgetSegment(
            id: "budget-baseline-overhead",
            layer: "Baseline Overhead",
            estimatedTokens: PromptLayerConstants.baselineOverhead,
            color: "orange"
        ))

        return result
    }

    // MARK: - Token Estimation Helpers

    private func estimateInstructionTokens(from projection: SessionProjection) -> Int {
        guard let instructions = projection.instructions else { return 0 }
        if let composed = instructions.composedInstructions.effectiveValue {
            return TokenEstimator.estimateTokenCount(composed)
        }
        return 0
    }

    private func estimateMemoryTokens(from projection: SessionProjection) -> Int {
        guard let instructions = projection.instructions else { return 0 }
        let topicCount = instructions.startupMemoryTopics.count + instructions.onDemandMemoryTopics.count
        // Memory topics are loaded but we don't have their content; estimate ~200 tokens per topic
        return topicCount > 0 ? topicCount * 200 : 0
    }

    // MARK: - Health

    /// Green if overhead < 15%, amber if 15–30%, red if > 30%.
    private func computeHealth() -> StageHealth {
        guard !segments.isEmpty else { return .noData }

        if overheadPercentage > 30 {
            return .errors(1)
        } else if overheadPercentage > 15 {
            return .warnings(1)
        }
        return .healthy
    }
}
