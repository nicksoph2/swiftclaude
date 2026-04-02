import XCTest
import SwiftUI
@testable import ClaudeConfigManager

/// Packet 26 tests — Global Search, Scope Stack Sidebar, and Keyboard Navigation.
final class Packet26Tests: XCTestCase {

    // MARK: - Helpers

    private func makeSource(
        scope: ResolutionScope,
        identifier: String = "settings.json",
        sourcePath: String? = nil
    ) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: identifier,
            displayName: nil,
            sourcePath: sourcePath
        )
    }

    private func makeEntry(
        keyPath: String,
        effectiveValue: JSONValue? = .bool(true),
        winningSource: ResolutionSource?,
        participants: [ResolutionSource],
        overridden: [ResolutionSource] = [],
        mergeMethod: MergeMethod = .selectHighestPrecedence
    ) -> ResolvedSettingsEntry {
        ResolvedSettingsEntry(
            keyPath: keyPath,
            value: ResolvedValue(
                effectiveValue: effectiveValue,
                winningSource: winningSource,
                trace: ResolutionTrace(
                    participants: participants,
                    overridden: overridden
                ),
                mergeMethod: mergeMethod
            )
        )
    }

    private func makeProjection(entries: [ResolvedSettingsEntry]) -> SessionProjection {
        let snapshot = ResolvedSettingsSnapshot(entries: entries)
        return SessionProjection(settings: snapshot)
    }

    // MARK: - testSearchReturnsSettingForKeyName

    @MainActor
    func testSearchReturnsSettingForKeyName() {
        let userSource = makeSource(scope: .user)
        let entry = makeEntry(
            keyPath: "model",
            effectiveValue: .string("claude-sonnet-4-20250514"),
            winningSource: userSource,
            participants: [userSource]
        )

        let viewModel = GlobalSearchViewModel()

        // Create a minimal pipeline and inject projection
        let pipeline = ConfigurationPipeline()
        pipeline.injectProjectionForTesting(makeProjection(entries: [entry]))
        viewModel.pipeline = pipeline

        // Perform search
        viewModel.performSearch("model")

        XCTAssertFalse(viewModel.results.isEmpty, "Expected at least one result for key 'model'")

        let settingResults = viewModel.results.filter { $0.kind == .setting }
        XCTAssertTrue(settingResults.contains { $0.title == "model" }, "Expected a setting result with title 'model'")
    }

    // MARK: - testSearchReturnsSettingForValue

    @MainActor
    func testSearchReturnsSettingForValue() {
        let userSource = makeSource(scope: .user)
        let entry = makeEntry(
            keyPath: "model",
            effectiveValue: .string("claude-sonnet-4-20250514"),
            winningSource: userSource,
            participants: [userSource]
        )

        let viewModel = GlobalSearchViewModel()
        let pipeline = ConfigurationPipeline()
        pipeline.injectProjectionForTesting(makeProjection(entries: [entry]))
        viewModel.pipeline = pipeline

        viewModel.performSearch("claude-sonnet")

        XCTAssertFalse(viewModel.results.isEmpty, "Expected at least one result for value containing 'claude-sonnet'")
    }

    // MARK: - testSearchReturnsNoResultsForUnknownQuery

    @MainActor
    func testSearchReturnsNoResultsForUnknownQuery() {
        let viewModel = GlobalSearchViewModel()
        let pipeline = ConfigurationPipeline()
        pipeline.injectProjectionForTesting(SessionProjection())
        viewModel.pipeline = pipeline

        viewModel.performSearch("zzzznonexistent")

        XCTAssertTrue(viewModel.results.isEmpty, "Expected no results for unknown query")
    }

    // MARK: - testSearchEmptyQueryReturnsEmptyResults

    @MainActor
    func testSearchEmptyQueryReturnsEmptyResults() {
        let viewModel = GlobalSearchViewModel()
        let pipeline = ConfigurationPipeline()
        viewModel.pipeline = pipeline

        viewModel.performSearch("")

        XCTAssertTrue(viewModel.results.isEmpty, "Expected empty results for empty query")
    }

    // MARK: - testSearchResultKindBadges

    func testSearchResultKindBadges() {
        XCTAssertEqual(SearchResultKind.setting.badge, "Setting")
        XCTAssertEqual(SearchResultKind.file.badge, "File")
        XCTAssertEqual(SearchResultKind.mcp.badge, "MCP")
        XCTAssertEqual(SearchResultKind.hook.badge, "Hook")
    }

    // MARK: - testSidebarDestinationsIncludeScopeStack

    func testSidebarDestinationsIncludeScopeStack() {
        let scopeDestinations: [SidebarDestination] = [.managed, .user, .project, .projectLocal, .session, .cli]

        for dest in scopeDestinations {
            XCTAssertTrue(dest.isScopeRow, "\(dest) should be a scope row")
            XCTAssertNotNil(dest.resolutionScope, "\(dest) should have a resolution scope")
        }

        // Non-scope destinations
        XCTAssertFalse(SidebarDestination.dashboard.isScopeRow)
        XCTAssertFalse(SidebarDestination.resolvedConfig.isScopeRow)
        XCTAssertFalse(SidebarDestination.tree.isScopeRow)
        XCTAssertFalse(SidebarDestination.permissions.isScopeRow)
        XCTAssertFalse(SidebarDestination.issues.isScopeRow)
    }

    // MARK: - testSidebarScopeToResolutionScopeMapping

    func testSidebarScopeToResolutionScopeMapping() {
        XCTAssertEqual(SidebarDestination.managed.resolutionScope, .managed)
        XCTAssertEqual(SidebarDestination.user.resolutionScope, .user)
        XCTAssertEqual(SidebarDestination.project.resolutionScope, .project)
        XCTAssertEqual(SidebarDestination.projectLocal.resolutionScope, .projectLocal)
        XCTAssertEqual(SidebarDestination.session.resolutionScope, .session)
        XCTAssertEqual(SidebarDestination.cli.resolutionScope, .cli)
        XCTAssertNil(SidebarDestination.dashboard.resolutionScope)
        XCTAssertNil(SidebarDestination.resolvedConfig.resolutionScope)
    }

    // MARK: - testSidebarResolvedConfigDestinationExists

    func testSidebarResolvedConfigDestinationExists() {
        XCTAssertTrue(
            SidebarDestination.allCases.contains(.resolvedConfig),
            "Resolved Config should be in sidebar destinations"
        )
        XCTAssertEqual(SidebarDestination.resolvedConfig.title, "Resolved Config")
    }

    // MARK: - testKeyboardShortcutActionsExist

    func testKeyboardShortcutActionsExist() {
        // Verify all shortcut actions produce a binding (not nil/crashing)
        let allActions: [GlobalShortcutAction] = [
            .search, .refresh, .dashboard, .resolvedConfig,
            .permissions, .issues, .pipelineView
        ]

        for action in allActions {
            let binding = action.shortcutBinding
            // Just verify binding exists and has .command modifier
            XCTAssertEqual(binding.1, .command, "\(action) should use .command modifier")
        }
    }

    // MARK: - testSuggestedSearches

    func testSuggestedSearches() {
        let suggestions = GlobalSearchViewModel.suggestedSearches
        XCTAssertTrue(suggestions.contains("model"))
        XCTAssertTrue(suggestions.contains("permissions.deny"))
        XCTAssertTrue(suggestions.contains("mcp"))
        XCTAssertTrue(suggestions.contains("hooks"))
        XCTAssertTrue(suggestions.contains("sandbox"))
    }

    // MARK: - testSidebarAllCasesOrder

    func testSidebarAllCasesOrder() {
        let allCases = SidebarDestination.allCases
        // Dashboard should be first
        XCTAssertEqual(allCases.first, .dashboard)
        // Usage Analytics should be last
        XCTAssertEqual(allCases.last, .usageAnalytics)
        // Verify scope stack order: managed > user > project > projectLocal > session > cli
        let scopeCases = allCases.filter { $0.isScopeRow }
        XCTAssertEqual(scopeCases, [.managed, .user, .project, .projectLocal, .session, .cli])
    }

    // MARK: - testSearchResultNavigationTargets

    @MainActor
    func testSearchResultNavigationTargets() {
        let userSource = makeSource(scope: .user)
        let entry = makeEntry(
            keyPath: "model",
            effectiveValue: .string("claude-sonnet-4-20250514"),
            winningSource: userSource,
            participants: [userSource]
        )

        let viewModel = GlobalSearchViewModel()
        let pipeline = ConfigurationPipeline()
        pipeline.injectProjectionForTesting(makeProjection(entries: [entry]))
        viewModel.pipeline = pipeline

        viewModel.performSearch("model")

        guard let result = viewModel.results.first else {
            XCTFail("Expected at least one result")
            return
        }

        XCTAssertEqual(result.stage, .resolution, "Setting results should target the resolution stage")
        XCTAssertNotNil(result.navigationTarget, "Setting results should have a navigation target")
    }
}
