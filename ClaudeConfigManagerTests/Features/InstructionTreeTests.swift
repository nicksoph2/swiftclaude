import XCTest
@testable import ClaudeConfigManager

final class InstructionTreeTests: XCTestCase {

    // MARK: - Helpers

    private func makeSource(
        scope: ResolutionScope,
        fileName: String
    ) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: fileName,
            displayName: fileName,
            sourcePath: "/fake/\(scope.rawValue)/\(fileName)"
        )
    }

    private func makeBlock(
        blockID: String,
        content: String,
        scope: ResolutionScope = .user,
        fileName: String = "CLAUDE.md"
    ) -> ResolvedInstructionBlock {
        let source = makeSource(scope: scope, fileName: fileName)
        return ResolvedInstructionBlock(
            blockID: blockID,
            content: ResolvedValue(
                effectiveValue: content,
                winningSource: source,
                trace: ResolutionTrace(participants: [source]),
                mergeMethod: .passthrough
            )
        )
    }

    private func makeSnapshot(
        blocks: [ResolvedInstructionBlock],
        edges: [ResolvedInstructionImportEdge] = []
    ) -> ResolvedInstructionSnapshot {
        let composed = ResolvedValue<String>(
            effectiveValue: blocks.compactMap { $0.content.effectiveValue }.joined(separator: "\n"),
            winningSource: blocks.first?.content.winningSource,
            trace: ResolutionTrace(participants: blocks.compactMap { $0.content.winningSource }),
            mergeMethod: .passthrough
        )
        return ResolvedInstructionSnapshot(
            composedInstructions: composed,
            orderedBlocks: blocks,
            importEdges: edges
        )
    }

    // MARK: - testLoadOrderIndexIsSequential

    /// Three CLAUDE.md files → load order indices 1, 2, 3.
    func testLoadOrderIndexIsSequential() {
        let blocks = [
            makeBlock(blockID: "block-a", content: "# Managed\n", scope: .managed, fileName: "CLAUDE.md"),
            makeBlock(blockID: "block-b", content: "# User\n",    scope: .user,    fileName: "CLAUDE.md"),
            makeBlock(blockID: "block-c", content: "# Project\n", scope: .project, fileName: "CLAUDE.md")
        ]

        let snapshot = makeSnapshot(blocks: blocks)
        let nodes = InstructionTreeBuilder.buildNodes(from: snapshot)

        XCTAssertEqual(nodes.count, 3)

        let indices = nodes.map(\.loadOrderIndex).sorted()
        XCTAssertEqual(indices, [1, 2, 3], "Load order indices should be sequential starting at 1")

        XCTAssertTrue(nodes.contains { $0.loadOrderIndex == 1 }, "Should have a first-loaded node")
        XCTAssertTrue(nodes.contains { $0.loadOrderIndex == 2 })
        XCTAssertTrue(nodes.contains { $0.loadOrderIndex == 3 }, "Should have a last-loaded node")

        // Only the highest-index node should be marked as last loaded
        XCTAssertEqual(nodes.filter(\.isLastLoaded).count, 1, "Exactly one node should be marked as last loaded")
        XCTAssertEqual(nodes.first(where: \.isLastLoaded)?.loadOrderIndex, 3)
    }

    // MARK: - testCycleDetected

    /// A → B → A creates a cycle; the semantic validator must emit an error.
    func testCycleDetected() {
        let blocks = [
            makeBlock(blockID: "block-a", content: "# A\n@file-b.md\n", scope: .user,    fileName: "file-a.md"),
            makeBlock(blockID: "block-b", content: "# B\n@file-a.md\n", scope: .project, fileName: "file-b.md")
        ]

        // Edge A → B (normal)
        let normalEdge = ResolvedInstructionImportEdge(
            parentBlockID: "block-a",
            childBlockID: "block-b",
            rawToken: "file-b.md",
            tokenRange: nil,
            resolvedPath: "/fake/file-b.md",
            depth: 1,
            isCycle: false
        )

        // Edge B → A (cycle — B tries to import A which is already in the chain)
        let cycleEdge = ResolvedInstructionImportEdge(
            parentBlockID: "block-b",
            childBlockID: nil,
            rawToken: "file-a.md",
            tokenRange: nil,
            resolvedPath: "/fake/file-a.md",
            depth: 2,
            isCycle: true
        )

        let snapshot = makeSnapshot(blocks: blocks, edges: [normalEdge, cycleEdge])
        let projection = SessionProjection(instructions: snapshot)

        let issues = SemanticProjectionValidator().validate(projection)

        let cycleIssues = issues.filter { $0.code == .semantic("instructions.importCycle") }
        XCTAssertFalse(cycleIssues.isEmpty, "Should emit at least one cycle error")
        XCTAssertEqual(cycleIssues.first?.severity, .error, "Cycle issue should be an error")
        XCTAssertTrue(
            cycleIssues.first?.message.contains("cycle") == true,
            "Cycle error message should mention 'cycle'"
        )
    }

    // MARK: - testNoCycleForLinearChain

    /// A → B → C (linear chain, no cycle) — no cycle error should be emitted.
    func testNoCycleForLinearChain() {
        let blocks = [
            makeBlock(blockID: "block-a", content: "# A\n", scope: .managed, fileName: "file-a.md"),
            makeBlock(blockID: "block-b", content: "# B\n", scope: .user,    fileName: "file-b.md"),
            makeBlock(blockID: "block-c", content: "# C\n", scope: .project, fileName: "file-c.md")
        ]

        let edgeAB = ResolvedInstructionImportEdge(
            parentBlockID: "block-a",
            childBlockID: "block-b",
            rawToken: "file-b.md",
            tokenRange: nil,
            resolvedPath: "/fake/file-b.md",
            depth: 1,
            isCycle: false
        )

        let edgeBC = ResolvedInstructionImportEdge(
            parentBlockID: "block-b",
            childBlockID: "block-c",
            rawToken: "file-c.md",
            tokenRange: nil,
            resolvedPath: "/fake/file-c.md",
            depth: 2,
            isCycle: false
        )

        let snapshot = makeSnapshot(blocks: blocks, edges: [edgeAB, edgeBC])
        let projection = SessionProjection(instructions: snapshot)

        let issues = SemanticProjectionValidator().validate(projection)

        let cycleIssues = issues.filter { $0.code == .semantic("instructions.importCycle") }
        XCTAssertTrue(cycleIssues.isEmpty, "Linear chain A→B→C should produce no cycle errors")
    }

    // MARK: - testTokenBudgetWarningAboveThreshold

    /// When total instruction tokens exceed 50,000 the builder reports it,
    /// and the semantic validator emits a token budget warning.
    func testTokenBudgetWarningAboveThreshold() {
        // ~4 bytes per token, so 200,001 bytes ≈ 50,000+ tokens
        let largeContent = String(repeating: "a", count: 200_001)

        let blocks = [makeBlock(blockID: "block-large", content: largeContent, scope: .user)]
        let snapshot = makeSnapshot(blocks: blocks)

        // Verify InstructionTreeBuilder reports above threshold
        let totalTokens = InstructionTreeBuilder.computeTotalTokens(from: snapshot)
        XCTAssertGreaterThanOrEqual(totalTokens, 50_000, "Total tokens should exceed threshold")

        // Verify the semantic validator emits a budget warning
        let projection = SessionProjection(instructions: snapshot)
        let issues = SemanticProjectionValidator().validate(projection)

        let budgetIssues = issues.filter { $0.code == .semantic("instructions.tokenBudgetExceeded") }
        XCTAssertFalse(budgetIssues.isEmpty, "Should emit a token budget warning when over threshold")
        XCTAssertEqual(budgetIssues.first?.severity, .warning)
    }

    // MARK: - testNoBannerBelowThreshold

    /// When total instruction tokens are below 50,000 no budget warning is emitted.
    func testNoBannerBelowThreshold() {
        // Small content well below threshold
        let smallContent = "# Instructions\nKeep responses concise.\n"

        let blocks = [makeBlock(blockID: "block-small", content: smallContent, scope: .user)]
        let snapshot = makeSnapshot(blocks: blocks)

        // Verify InstructionTreeBuilder reports below threshold
        let totalTokens = InstructionTreeBuilder.computeTotalTokens(from: snapshot)
        XCTAssertLessThan(totalTokens, 50_000, "Total tokens should be below threshold")

        // Verify hasCycles returns false for non-cycle snapshot
        XCTAssertFalse(InstructionTreeBuilder.hasCycles(in: snapshot), "No cycles in simple snapshot")

        // Verify the semantic validator does NOT emit a budget warning
        let projection = SessionProjection(instructions: snapshot)
        let issues = SemanticProjectionValidator().validate(projection)

        let budgetIssues = issues.filter { $0.code == .semantic("instructions.tokenBudgetExceeded") }
        XCTAssertTrue(budgetIssues.isEmpty, "Should not emit a budget warning when under threshold")
    }
}
