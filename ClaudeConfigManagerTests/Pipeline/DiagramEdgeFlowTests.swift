import XCTest
@testable import ClaudeConfigManager

/// Tests for Packet 13 — navigable arrows and health propagation.
@MainActor
final class DiagramEdgeFlowTests: XCTestCase {

    // MARK: - testFlowPanelContentForEachEdge

    /// Every non-terminal edge must have a non-empty flow explanation.
    func testFlowPanelContentForEachEdge() {
        // The canonical edges include one terminal self-loop for the output description;
        // verify that ALL eight entries (including the terminal) have non-empty text.
        XCTAssertEqual(DiagramEdge.all.count, 8,
                       "DiagramEdge.all must define exactly 8 edges")

        for edge in DiagramEdge.all {
            XCTAssertFalse(
                edge.flowExplanation.isEmpty,
                "Flow explanation must be non-empty for edge \(edge.id)"
            )
            XCTAssertFalse(
                edge.flowTitle.isEmpty,
                "Flow title must be non-empty for edge \(edge.id)"
            )
        }
    }

    /// Every non-terminal edge corresponds to one of the seven connections in DiagramLayout.
    func testNonTerminalEdgesMatchDiagramConnections() {
        let nonTerminal = DiagramEdge.all.filter { $0.from != $0.to }
        XCTAssertEqual(nonTerminal.count, DiagramLayout.connections.count,
                       "Non-terminal edge count must match DiagramLayout.connections.count")

        for conn in DiagramLayout.connections {
            let found = nonTerminal.contains { $0.from == conn.from && $0.to == conn.to }
            XCTAssertTrue(found,
                          "DiagramEdge.all is missing edge \(conn.from.rawValue)→\(conn.to.rawValue)")
        }
    }

    // MARK: - testHealthPropagationFromParsing

    /// Injecting a parsing error must produce propagated warning indicators on all
    /// edges whose source is Parsing or downstream of Parsing.
    func testHealthPropagationFromParsing() {
        // Build health map with a parsing error, everything else healthy / noData.
        var healthMap: [PipelineStage: StageHealth] = [:]
        for stage in PipelineStage.allCases {
            healthMap[stage] = stage == .parsing ? .errors(1) : .noData
        }

        let states = EdgeHealthPropagator.compute(stageHealthMap: healthMap)

        // Edges whose source is upstream of parsing (discovery→parsing) should NOT
        // carry the parsing error — the discovery stage itself is noData.
        let discoveryToParsing = "\(PipelineStage.discovery.rawValue)→\(PipelineStage.parsing.rawValue)"
        let discoveryState = states[discoveryToParsing]
        XCTAssertNotNil(discoveryState)
        // Discovery is noData, so only parsing-sourced issues would appear on this edge.
        // But the propagation rule says: issues from S and all stages UPSTREAM of S.
        // discoveryToParsing has source=discovery (idx 0), so only discovery's issues propagate.
        // Discovery is noData → no issues on this edge.
        XCTAssertFalse(
            discoveryState?.hasPropagatedIssue ?? true,
            "Discovery→Parsing edge should not carry the parsing error"
        )

        // Edges whose source is Parsing or downstream must have propagated issues.
        let downstreamEdges: [(PipelineStage, PipelineStage)] = [
            (.parsing, .resolution),
            (.resolution, .promptAssembly),
            (.promptAssembly, .toolExecution),
            (.toolExecution, .hooksLifecycle),
            (.hooksLifecycle, .mcpServers),
            (.mcpServers, .contextBudget),
        ]

        for (from, to) in downstreamEdges {
            let edgeID = "\(from.rawValue)→\(to.rawValue)"
            let state = states[edgeID]
            XCTAssertNotNil(state, "Missing state for edge \(edgeID)")
            XCTAssertTrue(
                state?.hasPropagatedIssue ?? false,
                "Edge \(edgeID) should carry the propagated parsing error"
            )
            XCTAssertEqual(
                state?.worstSeverity, .error,
                "Edge \(edgeID) worst severity should be .error"
            )
        }
    }

    // MARK: - testNoHealthDotWhenNoIssues

    /// When all stages are healthy or noData, no edge should carry a propagated issue.
    func testNoHealthDotWhenNoIssues() {
        var healthMap: [PipelineStage: StageHealth] = [:]
        for stage in PipelineStage.allCases {
            healthMap[stage] = .healthy
        }

        let states = EdgeHealthPropagator.compute(stageHealthMap: healthMap)

        for (_, state) in states {
            XCTAssertFalse(
                state.hasPropagatedIssue,
                "Edge \(state.id) should have no propagated issues when all stages are healthy"
            )
        }
    }

    /// noData stages also produce no propagated issues.
    func testNoHealthDotWhenAllNoData() {
        var healthMap: [PipelineStage: StageHealth] = [:]
        for stage in PipelineStage.allCases {
            healthMap[stage] = .noData
        }

        let states = EdgeHealthPropagator.compute(stageHealthMap: healthMap)

        for (_, state) in states {
            XCTAssertFalse(
                state.hasPropagatedIssue,
                "Edge \(state.id) should have no propagated issues when all stages are noData"
            )
        }
    }

    // MARK: - Additional edge cases

    /// Warning (not error) from MCP Servers propagates only to the mcpServers→contextBudget edge.
    func testWarningFromMCPServersPropagatesToContextBudgetOnly() {
        var healthMap: [PipelineStage: StageHealth] = [:]
        for stage in PipelineStage.allCases {
            healthMap[stage] = .noData
        }
        healthMap[.mcpServers] = .warnings(2)

        let states = EdgeHealthPropagator.compute(stageHealthMap: healthMap)

        // Only the mcpServers→contextBudget edge should carry the issue.
        let mcpEdgeID = "\(PipelineStage.mcpServers.rawValue)→\(PipelineStage.contextBudget.rawValue)"
        XCTAssertTrue(
            states[mcpEdgeID]?.hasPropagatedIssue ?? false,
            "mcpServers→contextBudget should carry propagated warning"
        )
        XCTAssertEqual(states[mcpEdgeID]?.worstSeverity, .warning)

        // All edges that are upstream of mcpServers must NOT carry this warning.
        let upstreamEdges = [
            "\(PipelineStage.discovery.rawValue)→\(PipelineStage.parsing.rawValue)",
            "\(PipelineStage.parsing.rawValue)→\(PipelineStage.resolution.rawValue)",
            "\(PipelineStage.resolution.rawValue)→\(PipelineStage.promptAssembly.rawValue)",
            "\(PipelineStage.promptAssembly.rawValue)→\(PipelineStage.toolExecution.rawValue)",
            "\(PipelineStage.toolExecution.rawValue)→\(PipelineStage.hooksLifecycle.rawValue)",
            "\(PipelineStage.hooksLifecycle.rawValue)→\(PipelineStage.mcpServers.rawValue)",
        ]

        for edgeID in upstreamEdges {
            XCTAssertFalse(
                states[edgeID]?.hasPropagatedIssue ?? true,
                "Upstream edge \(edgeID) must not carry MCP warning"
            )
        }
    }

    /// Error severity takes precedence over warning in worst-severity computation.
    func testErrorTakesPrecedenceOverWarningInWorstSeverity() {
        var healthMap: [PipelineStage: StageHealth] = [:]
        for stage in PipelineStage.allCases {
            healthMap[stage] = .noData
        }
        healthMap[.parsing] = .warnings(1)
        healthMap[.resolution] = .errors(1)

        let states = EdgeHealthPropagator.compute(stageHealthMap: healthMap)

        // resolution→promptAssembly should carry both a warning (from parsing) and error (from resolution)
        let edgeID = "\(PipelineStage.resolution.rawValue)→\(PipelineStage.promptAssembly.rawValue)"
        XCTAssertEqual(states[edgeID]?.worstSeverity, .error,
                       "Error must take precedence over warning in worstSeverity")
    }

    // MARK: - DiagramLayout midpoint

    func testArrowMidpointExistsForAllConnections() {
        for conn in DiagramLayout.connections {
            let mid = DiagramLayout.arrowMidpoint(from: conn.from, to: conn.to)
            XCTAssertNotNil(mid,
                            "arrowMidpoint must exist for \(conn.from.rawValue)→\(conn.to.rawValue)")
        }
    }
}
