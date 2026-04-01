import Foundation
import SwiftUI
import Combine

// MARK: - View Model

/// Transforms `SessionProjection` data into a layered prompt assembly visualization.
///
/// Builds an array of `PromptLayer` items representing the 6 layers of Claude's
/// assembled context window, with token estimates and instruction file details.
@MainActor
final class TreePromptAssemblyViewModel: ObservableObject {

    // MARK: - Published State

    /// The 6 prompt layers in assembly order.
    @Published private(set) var layers: [PromptLayer] = []

    /// Aggregate stage health based on instruction issues and data presence.
    @Published private(set) var stageHealth: StageHealth = .noData

    /// Total estimated overhead tokens before conversation begins.
    @Published private(set) var totalOverheadTokens: Int = 0

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
            layers = []
            stageHealth = .noData
            totalOverheadTokens = 0
            return
        }

        let builtLayers = buildLayers(from: projection)
        layers = builtLayers
        totalOverheadTokens = builtLayers.compactMap(\.estimatedTokens).reduce(0, +)
        stageHealth = computeHealth(from: projection)
    }

    // MARK: - Layer Building

    private func buildLayers(from projection: SessionProjection) -> [PromptLayer] {
        var result: [PromptLayer] = []

        // Layer 1: System Prompt
        result.append(buildSystemPromptLayer())

        // Layer 2: Tool Definitions
        result.append(buildToolDefinitionsLayer(from: projection))

        // Layer 3: CLAUDE.md Instructions
        result.append(buildInstructionsLayer(from: projection))

        // Layer 4: Auto-Memory
        result.append(buildAutoMemoryLayer(from: projection))

        // Layer 5: Conversation History
        result.append(buildConversationHistoryLayer())

        // Layer 6: Your Message
        result.append(buildUserMessageLayer())

        return result
    }

    // MARK: - Layer 1: System Prompt

    private func buildSystemPromptLayer() -> PromptLayer {
        let conditionalSections = [
            PromptLayer(
                id: "system-auto-mode",
                name: "Auto Mode",
                description: "Autonomous tool-use behavior directives",
                isConfigurable: false,
                isPresent: true
            ),
            PromptLayer(
                id: "system-plan-mode",
                name: "Plan Mode",
                description: "Planning-only behavior when plan mode is active",
                isConfigurable: false,
                isPresent: true
            ),
            PromptLayer(
                id: "system-learning-mode",
                name: "Learning Mode",
                description: "Explanation-oriented behavior for learning contexts",
                isConfigurable: false,
                isPresent: true
            ),
        ]

        return PromptLayer(
            id: "layer-system-prompt",
            name: "System Prompt",
            description: "Core behavioral instructions that define Claude's capabilities, safety guidelines, and interaction patterns. This is fixed by Anthropic and not configurable.",
            estimatedTokens: PromptLayerConstants.systemPromptTokens,
            isConfigurable: false,
            isPresent: true,
            children: conditionalSections
        )
    }

    // MARK: - Layer 2: Tool Definitions

    private func buildToolDefinitionsLayer(from projection: SessionProjection) -> PromptLayer {
        let builtInCount = BuiltInToolCatalog.tools.count
        let mcpServerCount = projection.mcp?.servers.count ?? 0

        var description = "\(builtInCount) built-in tools always available."
        if mcpServerCount > 0 {
            description += " \(mcpServerCount) MCP server\(mcpServerCount == 1 ? "" : "s") may contribute additional tools (loaded on demand)."
        }

        return PromptLayer(
            id: "layer-tool-definitions",
            name: "Tool Definitions",
            description: description,
            estimatedTokens: PromptLayerConstants.toolDefinitionTokens,
            isConfigurable: false,
            isPresent: true
        )
    }

    // MARK: - Layer 3: CLAUDE.md Instructions

    private func buildInstructionsLayer(from projection: SessionProjection) -> PromptLayer {
        guard let instructions = projection.instructions else {
            return PromptLayer(
                id: "layer-instructions",
                name: "CLAUDE.md Instructions",
                description: "No instruction files discovered.",
                isConfigurable: true,
                isPresent: false
            )
        }

        // Build child layers from ordered blocks
        let blockChildren = buildInstructionBlockChildren(
            blocks: instructions.orderedBlocks,
            importEdges: instructions.importEdges
        )

        // Estimate tokens from composed instructions
        let instructionTokens: Int?
        if let composed = instructions.composedInstructions.effectiveValue {
            instructionTokens = TokenEstimator.estimateTokenCount(composed)
        } else {
            instructionTokens = nil
        }

        let blockCount = instructions.orderedBlocks.count
        let importCount = instructions.importEdges.count
        var description = "\(blockCount) instruction file\(blockCount == 1 ? "" : "s") loaded in scope order."
        if importCount > 0 {
            description += " \(importCount) @import relationship\(importCount == 1 ? "" : "s") detected."
        }

        return PromptLayer(
            id: "layer-instructions",
            name: "CLAUDE.md Instructions",
            description: description,
            estimatedTokens: instructionTokens,
            isConfigurable: true,
            isPresent: !instructions.orderedBlocks.isEmpty,
            children: blockChildren
        )
    }

    /// Builds child `PromptLayer` items for each instruction block, with @import
    /// relationships represented as nested children.
    private func buildInstructionBlockChildren(
        blocks: [ResolvedInstructionBlock],
        importEdges: [ResolvedInstructionImportEdge]
    ) -> [PromptLayer] {
        // Build a lookup from parentBlockID to its import edges
        var edgesByParent: [String: [ResolvedInstructionImportEdge]] = [:]
        for edge in importEdges {
            edgesByParent[edge.parentBlockID, default: []].append(edge)
        }

        // Build a set of block IDs that are imported (i.e., appear as childBlockID)
        let importedBlockIDs = Set(importEdges.compactMap(\.childBlockID))

        // Only show top-level blocks (those NOT imported by another block)
        return blocks
            .filter { !importedBlockIDs.contains($0.blockID) }
            .map { block in
                buildBlockLayer(
                    block: block,
                    allBlocks: blocks,
                    edgesByParent: edgesByParent,
                    depth: 0
                )
            }
    }

    private func buildBlockLayer(
        block: ResolvedInstructionBlock,
        allBlocks: [ResolvedInstructionBlock],
        edgesByParent: [String: [ResolvedInstructionImportEdge]],
        depth: Int
    ) -> PromptLayer {
        let content = block.content.effectiveValue ?? ""
        let tokens = content.isEmpty ? nil : TokenEstimator.estimateTokenCount(content)

        // Content preview: first 3 lines
        let preview = contentPreview(content, maxLines: 3)

        // Source scope and path
        let scope = block.content.winningSource?.scope
        let sourcePath = block.content.winningSource?.sourcePath
        let displayName = block.content.winningSource?.displayName
            ?? sourcePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? block.blockID

        var description = ""
        if let scope {
            description = "[\(scope.rawValue.localizedCapitalized)]"
        }
        if let sourcePath {
            description += description.isEmpty ? sourcePath : " — \(sourcePath)"
        }

        // Recursively build children from @import edges
        let edges = edgesByParent[block.blockID] ?? []
        let children: [PromptLayer] = edges.compactMap { edge in
            if edge.isCycle {
                // Show cycle warning as a leaf
                return PromptLayer(
                    id: "import-cycle-\(edge.rawToken)",
                    name: "⚠ Circular @import: \(edge.rawToken)",
                    description: "This @import creates a cycle and is skipped.",
                    isConfigurable: false,
                    isPresent: false
                )
            }
            guard let childID = edge.childBlockID,
                  let childBlock = allBlocks.first(where: { $0.blockID == childID }),
                  depth < 10 // Safety guard against deep nesting
            else {
                // Unresolved import
                return PromptLayer(
                    id: "import-unresolved-\(edge.rawToken)",
                    name: "@import \(edge.rawToken)",
                    description: edge.resolvedPath ?? "Unresolved import target",
                    isConfigurable: false,
                    isPresent: false
                )
            }
            return buildBlockLayer(
                block: childBlock,
                allBlocks: allBlocks,
                edgesByParent: edgesByParent,
                depth: depth + 1
            )
        }

        return PromptLayer(
            id: "instruction-\(block.blockID)",
            name: displayName,
            description: description,
            estimatedTokens: tokens,
            isConfigurable: true,
            isPresent: true,
            children: children,
            expandedContent: preview
        )
    }

    // MARK: - Layer 4: Auto-Memory

    private func buildAutoMemoryLayer(from projection: SessionProjection) -> PromptLayer {
        guard let instructions = projection.instructions else {
            return PromptLayer(
                id: "layer-auto-memory",
                name: "Auto-Memory",
                description: "No memory data available.",
                isConfigurable: true,
                isPresent: false
            )
        }

        let startupTopics = instructions.startupMemoryTopics
        let onDemandTopics = instructions.onDemandMemoryTopics
        let totalTopics = startupTopics.count + onDemandTopics.count

        guard totalTopics > 0 else {
            return PromptLayer(
                id: "layer-auto-memory",
                name: "Auto-Memory",
                description: "No memory topics configured.",
                estimatedTokens: 0,
                isConfigurable: true,
                isPresent: false
            )
        }

        var children: [PromptLayer] = []

        if !startupTopics.isEmpty {
            let startupChildren = startupTopics.map { topic in
                PromptLayer(
                    id: "memory-startup-\(topic.topicID)",
                    name: topic.title,
                    description: "Startup topic — loaded at session start"
                )
            }
            children.append(PromptLayer(
                id: "memory-startup-group",
                name: "Startup Topics",
                description: "\(startupTopics.count) topic\(startupTopics.count == 1 ? "" : "s") loaded at session start",
                children: startupChildren
            ))
        }

        if !onDemandTopics.isEmpty {
            let onDemandChildren = onDemandTopics.map { topic in
                PromptLayer(
                    id: "memory-ondemand-\(topic.topicID)",
                    name: topic.title,
                    description: "On-demand topic — loaded when referenced"
                )
            }
            children.append(PromptLayer(
                id: "memory-ondemand-group",
                name: "On-Demand Topics",
                description: "\(onDemandTopics.count) topic\(onDemandTopics.count == 1 ? "" : "s") loaded when referenced",
                children: onDemandChildren
            ))
        }

        return PromptLayer(
            id: "layer-auto-memory",
            name: "Auto-Memory",
            description: "\(totalTopics) memory topic\(totalTopics == 1 ? "" : "s") configured. First 200 lines / 25KB loaded at startup.",
            isConfigurable: true,
            isPresent: true,
            children: children
        )
    }

    // MARK: - Layer 5: Conversation History

    private func buildConversationHistoryLayer() -> PromptLayer {
        PromptLayer(
            id: "layer-conversation-history",
            name: "Conversation History",
            description: "Grows during the session as you exchange messages with Claude. Auto-compacts at approximately 95% context usage to free space.",
            estimatedTokens: 0,
            isConfigurable: false,
            isPresent: true
        )
    }

    // MARK: - Layer 6: Your Message

    private func buildUserMessageLayer() -> PromptLayer {
        PromptLayer(
            id: "layer-user-message",
            name: "Your Message",
            description: "Your current prompt and any attached files or images.",
            estimatedTokens: 0,
            isConfigurable: false,
            isPresent: true
        )
    }

    // MARK: - Health

    private func computeHealth(from projection: SessionProjection) -> StageHealth {
        guard let instructions = projection.instructions else { return .noData }

        var errorCount = 0
        var warningCount = 0

        for issue in instructions.issues {
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

    // MARK: - Helpers

    /// Returns the first N lines of text as a preview string.
    private func contentPreview(_ text: String, maxLines: Int) -> String {
        guard !text.isEmpty else { return "" }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let previewLines = lines.prefix(maxLines)
        var preview = previewLines.joined(separator: "\n")
        if lines.count > maxLines {
            preview += "\n…"
        }
        return preview
    }
}
