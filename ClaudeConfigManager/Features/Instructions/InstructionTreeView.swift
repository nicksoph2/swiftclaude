import SwiftUI
import AppKit

// MARK: - Domain Models

/// Represents a single CLAUDE.md file node in the instruction composition tree.
struct InstructionTreeNode: Identifiable, Equatable {
    let id: String                       // blockID
    let fileName: String                 // e.g. "CLAUDE.md"
    let scope: ResolutionScope?
    let loadOrderIndex: Int              // 1-based position across all orderedBlocks
    let tokenCount: Int
    let isLastLoaded: Bool               // true for the highest loadOrderIndex
    let sourcePath: String?
    let content: String
    let isCycleParticipant: Bool         // has at least one outgoing cycle edge
    let importedEdges: [InstructionImportEdgeModel]
}

/// Represents an @import edge from a parent node.
struct InstructionImportEdgeModel: Identifiable, Equatable {
    var id: String { "\(parentBlockID)-\(rawToken)" }
    let parentBlockID: String
    let rawToken: String
    let resolvedPath: String?
    let isCycle: Bool
    let childNode: InstructionTreeNode?  // nil = unresolved (ghost node)
}

// MARK: - Builder

/// Builds the `InstructionTreeNode` hierarchy from a `ResolvedInstructionSnapshot`.
enum InstructionTreeBuilder {

    /// Builds the top-level list of nodes (those not imported by any other node).
    static func buildNodes(from snapshot: ResolvedInstructionSnapshot) -> [InstructionTreeNode] {
        let blocks = snapshot.orderedBlocks
        let edges = snapshot.importEdges

        // Map blockID → its index in orderedBlocks (1-based load order)
        let loadOrderByBlockID: [String: Int] = Dictionary(
            uniqueKeysWithValues: blocks.enumerated().map { ($1.blockID, $0 + 1) }
        )

        let maxOrder = blocks.count

        // Which blocks are imported by some other block (not top-level)?
        let importedBlockIDs = Set(edges.compactMap(\.childBlockID))

        // Index edges by parent
        var edgesByParent: [String: [ResolvedInstructionImportEdge]] = [:]
        for edge in edges {
            edgesByParent[edge.parentBlockID, default: []].append(edge)
        }

        // IDs of blocks that are direct participants in a cycle (have outgoing cycle edge)
        let cycleParentIDs = Set(edges.filter(\.isCycle).map(\.parentBlockID))

        // Build all nodes first (flat map), then wire up edges recursively
        func buildNode(for block: ResolvedInstructionBlock, visited: Set<String>) -> InstructionTreeNode {
            let order = loadOrderByBlockID[block.blockID] ?? 0
            let rawContent = block.content.effectiveValue ?? ""
            let sourcePath = block.content.winningSource?.sourcePath
            let displayName = block.content.winningSource?.displayName
                ?? sourcePath.map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? block.blockID
            let scope = block.content.winningSource?.scope
            let tokens = rawContent.isEmpty ? 0 : TokenEstimator.estimateTokenCount(rawContent)

            var nextVisited = visited
            nextVisited.insert(block.blockID)

            let importEdges: [InstructionImportEdgeModel] = (edgesByParent[block.blockID] ?? []).map { edge in
                var childNode: InstructionTreeNode?
                if let childID = edge.childBlockID,
                   !edge.isCycle,
                   !visited.contains(childID),
                   let childBlock = blocks.first(where: { $0.blockID == childID }) {
                    childNode = buildNode(for: childBlock, visited: nextVisited)
                }
                return InstructionImportEdgeModel(
                    parentBlockID: block.blockID,
                    rawToken: edge.rawToken,
                    resolvedPath: edge.resolvedPath,
                    isCycle: edge.isCycle,
                    childNode: childNode
                )
            }

            return InstructionTreeNode(
                id: block.blockID,
                fileName: displayName,
                scope: scope,
                loadOrderIndex: order,
                tokenCount: tokens,
                isLastLoaded: order == maxOrder,
                sourcePath: sourcePath,
                content: rawContent,
                isCycleParticipant: cycleParentIDs.contains(block.blockID),
                importedEdges: importEdges
            )
        }

        return blocks
            .filter { !importedBlockIDs.contains($0.blockID) }
            .map { buildNode(for: $0, visited: []) }
    }

    /// Sums token counts across all resolved blocks.
    static func computeTotalTokens(from snapshot: ResolvedInstructionSnapshot) -> Int {
        snapshot.orderedBlocks.reduce(0) { total, block in
            total + TokenEstimator.estimateTokenCount(block.content.effectiveValue ?? "")
        }
    }

    /// Returns true if any import edge is marked as a cycle.
    static func hasCycles(in snapshot: ResolvedInstructionSnapshot) -> Bool {
        snapshot.importEdges.contains { $0.isCycle }
    }
}

// MARK: - Main View

/// Visual tree showing how CLAUDE.md instruction files compose across scopes.
/// Placed inside the Prompt Assembly stage of the Pipeline view.
struct InstructionTreeView: View {

    let snapshot: ResolvedInstructionSnapshot

    @State private var previewNode: InstructionTreeNode?

    private var nodes: [InstructionTreeNode] {
        InstructionTreeBuilder.buildNodes(from: snapshot)
    }

    private var totalTokens: Int {
        InstructionTreeBuilder.computeTotalTokens(from: snapshot)
    }

    private var hasCycles: Bool {
        InstructionTreeBuilder.hasCycles(in: snapshot)
    }

    private var cycleEdges: [ResolvedInstructionImportEdge] {
        snapshot.importEdges.filter { $0.isCycle }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Section header ──
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.indent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Instruction Composition")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(snapshot.orderedBlocks.count) file\(snapshot.orderedBlocks.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // ── Banners ──
            if hasCycles {
                InstructionCycleBanner(
                    cycleEdges: cycleEdges,
                    allBlocks: snapshot.orderedBlocks
                )
            }

            if totalTokens >= 50_000 {
                InstructionTokenBudgetBanner(
                    totalTokens: totalTokens,
                    blocks: snapshot.orderedBlocks
                )
            }

            // ── Tree ──
            if nodes.isEmpty {
                Text("No instruction files loaded.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(nodes) { node in
                        InstructionNodeRow(
                            node: node,
                            depth: 0,
                            totalNodes: snapshot.orderedBlocks.count,
                            onNodeTapped: { tapped in previewNode = tapped }
                        )
                    }
                }
            }
        }
        .popover(item: $previewNode) { node in
            InstructionPreviewPopover(node: node)
        }
    }
}

// MARK: - Cycle Detection Banner

struct InstructionCycleBanner: View {
    let cycleEdges: [ResolvedInstructionImportEdge]
    let allBlocks: [ResolvedInstructionBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Import cycle detected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }

            ForEach(Array(cycleEdges.enumerated()), id: \.offset) { _, edge in
                let parentFile = fileName(forBlockID: edge.parentBlockID)
                let cyclePath = "\(parentFile) → \(edge.rawToken) → \(parentFile) (cycle)"
                Text(cyclePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.8))
            }

            Text("The cycling file will not be loaded because of this cycle. Instructions from this file are missing from Claude's context.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private func fileName(forBlockID blockID: String) -> String {
        guard let block = allBlocks.first(where: { $0.blockID == blockID }) else { return blockID }
        if let path = block.content.winningSource?.sourcePath {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return block.content.winningSource?.displayName ?? blockID
    }
}

// MARK: - Token Budget Banner

struct InstructionTokenBudgetBanner: View {
    let totalTokens: Int
    let blocks: [ResolvedInstructionBlock]

    @State private var tipsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Your instruction files are large — \(formattedTokens(totalTokens)) tokens estimated across \(blocks.count) file\(blocks.count == 1 ? "" : "s"). This may consume a significant portion of Claude's context window.")
                    .font(.caption)
            }

            tokenBarChart

            DisclosureGroup("Tips", isExpanded: $tipsExpanded) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Use @import selectively to avoid loading large files in every session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Break large instruction files into smaller, more targeted ones.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .font(.caption.weight(.medium))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var tokenBarChart: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(blocks, id: \.blockID) { block in
                    let blockTokens = TokenEstimator.estimateTokenCount(block.content.effectiveValue ?? "")
                    let fraction = totalTokens > 0 ? Double(blockTokens) / Double(totalTokens) : 0
                    let scope = block.content.winningSource?.scope
                    let label = fileLabel(for: block)

                    Rectangle()
                        .fill(ScopeColorScheme.color(for: scope ?? .synthetic).opacity(0.7))
                        .frame(width: max(2.0, geo.size.width * fraction))
                        .help("\(label): ~\(formattedTokens(blockTokens)) tokens")
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func fileLabel(for block: ResolvedInstructionBlock) -> String {
        if let path = block.content.winningSource?.sourcePath {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return block.content.winningSource?.displayName ?? block.blockID
    }

    private func formattedTokens(_ count: Int) -> String {
        count >= 1_000 ? String(format: "%.1fK", Double(count) / 1_000.0) : "\(count)"
    }
}

// MARK: - Node Row

/// Renders a single instruction file node and its imported children recursively.
struct InstructionNodeRow: View {
    let node: InstructionTreeNode
    let depth: Int
    let totalNodes: Int
    let onNodeTapped: (InstructionTreeNode) -> Void

    private var loadFraction: Double {
        guard totalNodes > 1 else { return 1.0 }
        return Double(node.loadOrderIndex) / Double(totalNodes)
    }

    private var backgroundOpacity: Double { 0.35 + 0.65 * loadFraction }
    private var borderWidth: CGFloat { CGFloat(0.5 + 1.5 * loadFraction) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            nodeCard

            if !node.importedEdges.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(node.importedEdges) { edge in
                        HStack(alignment: .top, spacing: 0) {
                            connectorLine
                            VStack(alignment: .leading, spacing: 4) {
                                importLabel
                                edgeContent(edge)
                            }
                            .padding(.leading, 6)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
    }

    // MARK: - Node Card

    private var nodeCard: some View {
        Button {
            onNodeTapped(node)
        } label: {
            HStack(spacing: 8) {
                loadOrderBadge

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(node.fileName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        if node.isLastLoaded {
                            Text("Last loaded")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentColor.opacity(0.15))
                                )
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    HStack(spacing: 6) {
                        if let scope = node.scope {
                            ScopeColorScheme.scopeBadge(for: scope)
                        }

                        Text("~\(node.tokenCount) tokens")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(nodeBorderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private var loadOrderBadge: some View {
        Text("\(node.loadOrderIndex)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(node.isCycleParticipant ? Color.red : ScopeColorScheme.color(for: node.scope ?? .synthetic))
            )
    }

    private var nodeBorderColor: Color {
        node.isCycleParticipant
            ? Color.red
            : ScopeColorScheme.color(for: node.scope ?? .synthetic).opacity(0.5)
    }

    // MARK: - Connector Line

    private var connectorLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1)
    }

    // MARK: - Import Label

    private var importLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("@import")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 2)
    }

    // MARK: - Edge Content

    @ViewBuilder
    private func edgeContent(_ edge: InstructionImportEdgeModel) -> some View {
        if edge.isCycle {
            cycleChildRow(edge: edge)
        } else if let child = edge.childNode {
            InstructionNodeRow(
                node: child,
                depth: depth + 1,
                totalNodes: totalNodes,
                onNodeTapped: onNodeTapped
            )
        } else {
            ghostNodeRow(edge: edge)
        }
    }

    private func cycleChildRow(edge: InstructionImportEdgeModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .foregroundStyle(.red)

            Text(edge.rawToken)
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)

            Text("cycle")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.12)))
                .foregroundStyle(.red)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    Color.red.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
    }

    private func ghostNodeRow(edge: InstructionImportEdgeModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.square.dashed")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(edge.rawToken)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Not found")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.12)))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
    }
}

// MARK: - Content Preview Popover

/// Full content preview shown when tapping a node.
struct InstructionPreviewPopover: View {
    let node: InstructionTreeNode

    @Environment(\.dismiss) private var dismiss

    private var lineCount: Int {
        node.content.components(separatedBy: "\n").count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(node.fileName)
                        .font(.headline.weight(.semibold))

                    if let scope = node.scope {
                        ScopeColorScheme.scopeBadge(for: scope)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    Label("~\(node.tokenCount) tokens", systemImage: "textformat.size")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(lineCount) lines", systemImage: "list.number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            Divider()

            // Content scroll view
            ScrollView {
                Text(node.content.isEmpty ? "(empty file)" : node.content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(node.content.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

            Divider()

            // Footer actions
            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.content, forType: .string)
                } label: {
                    Label("Copy to clipboard", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                if let path = node.sourcePath {
                    Button {
                        let url = URL(fileURLWithPath: path)
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Edit this file", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {} label: {
                        Label("Edit this file", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .help("Coming soon — file editing will be available in a future release")
                }

                Spacer()
            }
            .padding(12)
        }
        .frame(width: 520, height: 400)
    }
}
