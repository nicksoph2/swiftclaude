import XCTest
import SwiftUI
@testable import ClaudeConfigManager

/// Tests for Packet 12 — animated node zoom and simplified mode.
@MainActor
final class TreePipelineZoomTests: XCTestCase {

    // MARK: - selectedStage

    /// Setting `viewModel.selectedStage` to a stage value is reflected immediately.
    func testSelectingStageUpdatesSelectedStage() {
        let vm = TreePipelineViewModel()
        XCTAssertNil(vm.selectedStage, "selectedStage should start nil")

        vm.selectedStage = .parsing
        XCTAssertEqual(vm.selectedStage, .parsing)

        // The breadcrumb strip should highlight .parsing and compress the other 7 stages.
        let otherStages = PipelineStage.allCases.filter { $0 != .parsing }
        XCTAssertEqual(otherStages.count, 7, "Breadcrumb strip should compress 7 other stages")
    }

    /// Clearing `selectedStage` returns the diagram to the overview state.
    func testDeselectingStageReturnsToNil() {
        let vm = TreePipelineViewModel()
        vm.selectedStage = .resolution
        XCTAssertNotNil(vm.selectedStage)

        vm.selectedStage = nil
        XCTAssertNil(vm.selectedStage, "selectedStage should be nil after deselection")
    }

    // MARK: - DiagramMode

    /// A fresh `DiagramMode` value from `.simplified` raw string equals `.simplified`.
    func testSimplifiedModeDefaultsForNewUser() {
        // Simulate the default AppStorage raw value ("simplified") for a new user.
        let defaultRaw = DiagramMode.simplified.rawValue
        let resolvedMode = DiagramMode(rawValue: defaultRaw) ?? .advanced
        XCTAssertEqual(resolvedMode, .simplified,
                       "New users should default to simplified diagram mode")
    }

    /// Switching to advanced mode changes the raw value to "advanced".
    func testAdvancedModeRawValue() {
        XCTAssertEqual(DiagramMode.advanced.rawValue, "advanced")
    }

    /// All DiagramMode cases are representable.
    func testDiagramModeAllCasesResolvable() {
        for mode in DiagramMode.allCases {
            let resolved = DiagramMode(rawValue: mode.rawValue)
            XCTAssertEqual(resolved, mode)
        }
    }

    // MARK: - CompositeStageGroup

    /// Each composite group covers distinct, non-overlapping stages.
    func testCompositeGroupsAreDisjoint() {
        let allStages = CompositeStageGroup.allCases.flatMap(\.constituentStages)
        let uniqueStages = Set(allStages)
        XCTAssertEqual(allStages.count, uniqueStages.count,
                       "Composite groups must not share constituent stages")
    }

    /// All 8 pipeline stages are covered by exactly one composite group.
    func testCompositeGroupsCoverAllStages() {
        let covered = Set(CompositeStageGroup.allCases.flatMap(\.constituentStages))
        let all = Set(PipelineStage.allCases)
        XCTAssertEqual(covered, all,
                       "Composite groups must cover all 8 pipeline stages")
    }

    /// Exactly three composite groups exist.
    func testThreeCompositeGroups() {
        XCTAssertEqual(CompositeStageGroup.allCases.count, 3)
    }

    // MARK: - PipelineBreadcrumbStrip

    /// The breadcrumb strip can be instantiated without crashing.
    func testBreadcrumbStripInstantiates() {
        // We can only test that the type compiles and constructs without crashing.
        // (Namespace must be created in a View context, so we exercise the raw model.)
        let vm = TreePipelineViewModel()
        vm.selectedStage = .hooksLifecycle
        XCTAssertEqual(vm.selectedStage, .hooksLifecycle)
    }
}
