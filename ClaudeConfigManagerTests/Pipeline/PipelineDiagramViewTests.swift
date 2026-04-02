import XCTest
import SwiftUI
@testable import ClaudeConfigManager

/// Verifies that `PipelineDiagramView` and its supporting types compile and
/// can be instantiated with mock data without crashing.
@MainActor
final class PipelineDiagramViewTests: XCTestCase {

    // MARK: - Mock Data

    func testPreviewMockDataCoversAllStages() {
        let statuses = PipelineStageStatus.preview
        let stagesInMock = Set(statuses.map(\.stage))
        let allStages = Set(PipelineStage.allCases)
        XCTAssertEqual(stagesInMock, allStages, "Preview mock data must cover all 8 pipeline stages")
    }

    // MARK: - DiagramLayout

    func testLayoutPositionsExistForAllStages() {
        for stage in PipelineStage.allCases {
            XCTAssertNotNil(
                DiagramLayout.nodePositions[stage],
                "DiagramLayout must define a position for \(stage.title)"
            )
        }
    }

    func testLayoutConnectionCountIs7() {
        // 8 stages connected in a chain → 7 arrows
        XCTAssertEqual(DiagramLayout.connections.count, 7)
    }

    func testLayoutRow1IsLeftToRight() {
        let discovery = DiagramLayout.nodePositions[.discovery]!
        let parsing   = DiagramLayout.nodePositions[.parsing]!
        let resolution = DiagramLayout.nodePositions[.resolution]!
        let prompt    = DiagramLayout.nodePositions[.promptAssembly]!

        XCTAssertLessThan(discovery.x, parsing.x)
        XCTAssertLessThan(parsing.x, resolution.x)
        XCTAssertLessThan(resolution.x, prompt.x)

        // All on the same row
        XCTAssertEqual(discovery.y, parsing.y)
        XCTAssertEqual(parsing.y, resolution.y)
        XCTAssertEqual(resolution.y, prompt.y)
    }

    func testLayoutRow2IsRightToLeft() {
        let tool     = DiagramLayout.nodePositions[.toolExecution]!
        let hooks    = DiagramLayout.nodePositions[.hooksLifecycle]!
        let mcp      = DiagramLayout.nodePositions[.mcpServers]!
        let budget   = DiagramLayout.nodePositions[.contextBudget]!

        // Flow is right-to-left, so tool is rightmost
        XCTAssertGreaterThan(tool.x, hooks.x)
        XCTAssertGreaterThan(hooks.x, mcp.x)
        XCTAssertGreaterThan(mcp.x, budget.x)

        // All on the same row
        XCTAssertEqual(tool.y, hooks.y)
        XCTAssertEqual(hooks.y, mcp.y)
        XCTAssertEqual(mcp.y, budget.y)
    }

    func testLayoutRow2IsBelowRow1() {
        let row1Y = DiagramLayout.nodePositions[.discovery]!.y
        let row2Y = DiagramLayout.nodePositions[.toolExecution]!.y
        XCTAssertGreaterThan(row2Y, row1Y)
    }

    func testScaleFactorNeverExceedsOne() {
        // Container larger than design → scale stays at 1.0
        let large = CGSize(width: 2000, height: 2000)
        XCTAssertEqual(DiagramLayout.scaleFactor(for: large), 1.0)
    }

    func testScaleFactorScalesDownForSmallContainer() {
        let small = CGSize(width: 440, height: 170)
        let scale = DiagramLayout.scaleFactor(for: small)
        XCTAssertLessThan(scale, 1.0)
        XCTAssertGreaterThan(scale, 0.0)
    }

    // MARK: - View Model Instantiation

    func testViewModelInstantiatesWithAllStageHealth() {
        let vm = TreePipelineViewModel()
        // Should initialise with noData for every stage
        XCTAssertEqual(vm.stageHealthEntries.count, PipelineStage.allCases.count)
        for entry in vm.stageHealthEntries {
            if case .noData = entry.health { /* expected */ } else {
                XCTFail("Initial health for \(entry.stage.title) should be .noData")
            }
        }
    }

    // MARK: - PipelineStageStatus

    func testStageStatusDefaultsToNoData() {
        let status = PipelineStageStatus(stage: .discovery)
        if case .noData = status.health {
            // expected
        } else {
            XCTFail("Default health should be .noData")
        }
        XCTAssertTrue(status.metricLabel.isEmpty)
        XCTAssertTrue(status.activeScopes.isEmpty)
    }

    // MARK: - Arrow Paths

    func testArrowPathsAreNonEmpty() {
        for conn in DiagramLayout.connections {
            let path = DiagramLayout.arrowPath(from: conn.from, to: conn.to)
            XCTAssertFalse(path.isEmpty, "Arrow path from \(conn.from) to \(conn.to) should not be empty")
        }
    }

    func testArrowheadPathsAreNonEmpty() {
        for conn in DiagramLayout.connections {
            let path = DiagramLayout.arrowheadPath(from: conn.from, to: conn.to)
            XCTAssertFalse(path.isEmpty, "Arrowhead from \(conn.from) to \(conn.to) should not be empty")
        }
    }
}
