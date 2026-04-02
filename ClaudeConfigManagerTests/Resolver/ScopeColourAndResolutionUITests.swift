import XCTest
@testable import ClaudeConfigManager

/// Packet 14 tests — merge method labels and conflict badge logic.
@MainActor
final class ScopeColourAndResolutionUITests: XCTestCase {

    // MARK: - Part B: Merge Method Labels

    func testMergeLabelForEachMergeMethod() {
        // Override-type methods
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .selectHighestPrecedence),
            "Overrides — highest scope wins"
        )
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .replace),
            "Overrides — highest scope wins"
        )

        // Merge-type methods
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .append),
            "Merges — all scopes combined"
        )
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .appendUnique),
            "Merges — all scopes combined"
        )
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .setUnion),
            "Merges — all scopes combined"
        )

        // Deep-merge-type methods
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .deepMergeObject),
            "Deep merges — per-key precedence"
        )
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .keyedByIdentifier),
            "Deep merges — per-key precedence"
        )

        // Passthrough
        XCTAssertEqual(
            TreeResolutionViewModel.mergeMethodLabel(for: .passthrough),
            "Passthrough"
        )
    }

    func testMergeMethodIconsAreAssigned() {
        // Override icons
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .selectHighestPrecedence), "chevron.up")
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .replace), "chevron.up")

        // Merge icons
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .append), "arrow.triangle.merge")
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .appendUnique), "arrow.triangle.merge")
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .setUnion), "arrow.triangle.merge")

        // Deep merge icons
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .deepMergeObject), "square.3.layers.3d")
        XCTAssertEqual(TreeResolutionViewModel.mergeMethodIcon(for: .keyedByIdentifier), "square.3.layers.3d")
    }

    func testMergeMethodDeveloperIDMatchesRawValue() {
        let allMethods: [MergeMethod] = [
            .selectHighestPrecedence, .replace, .deepMergeObject,
            .append, .appendUnique, .setUnion, .keyedByIdentifier, .passthrough
        ]
        for method in allMethods {
            XCTAssertEqual(
                TreeResolutionViewModel.mergeMethodDeveloperID(for: method),
                method.rawValue,
                "Developer ID should match rawValue for \(method)"
            )
        }
    }

    // MARK: - Part C: Conflict Badge Logic

    func testConflictBadgeAppearsForContestedKey() {
        // A setting with two participants where one is overridden → hasConflict = true
        let entry = ResolutionEntryDisplay(
            id: "apiKey",
            keyPath: "apiKey",
            effectiveValueString: "\"prod-key\"",
            winningScope: .managed,
            winningSourcePath: "/managed/settings.json",
            mergeMethod: .selectHighestPrecedence,
            mergeMethodLabel: "Overrides — highest scope wins",
            overriddenCount: 1,
            participantCount: 2,
            waterfallNodes: [],
            hasConflict: true,
            isMergedArray: false,
            resolvedEntry: nil
        )

        XCTAssertTrue(entry.hasConflict, "Entry with overridden sources should be flagged as conflicted")
        XCTAssertEqual(entry.overriddenCount, 1)
    }

    func testNoConflictBadgeForUncontestedKey() {
        // A setting with only one contributor → hasConflict = false
        let entry = ResolutionEntryDisplay(
            id: "model",
            keyPath: "model",
            effectiveValueString: "\"claude-3\"",
            winningScope: .user,
            winningSourcePath: "/user/settings.json",
            mergeMethod: .selectHighestPrecedence,
            mergeMethodLabel: "Overrides — highest scope wins",
            overriddenCount: 0,
            participantCount: 1,
            waterfallNodes: [],
            hasConflict: false,
            isMergedArray: false,
            resolvedEntry: nil
        )

        XCTAssertFalse(entry.hasConflict, "Entry with no overridden sources should not be flagged as conflicted")
    }
}
