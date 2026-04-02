import XCTest
@testable import ClaudeConfigManager

final class ScopeRecommendationEngineTests: XCTestCase {
    let engine = ScopeRecommendationEngine()

    func testManagedKeyIsNotEditable() {
        // Build a projection with a managed-locked setting
        let managedSource = ResolutionSource(
            scope: .managed,
            kind: .file,
            identifier: "managed-settings",
            displayName: "Server-managed settings",
            sourcePath: "/etc/claude/managed.json",
            availability: .present
        )

        let trace = ResolutionTrace(
            participants: [managedSource],
            overridden: []
        )

        let entry = ResolvedSettingsEntry(
            keyPath: "model",
            value: ResolvedValue(
                effectiveValue: .string("claude-opus"),
                winningSource: managedSource,
                trace: trace,
                mergeMethod: .selectHighestPrecedence
            )
        )

        let settings = ResolvedSettingsSnapshot(entries: [entry])
        let projection = SessionProjection(settings: settings)

        // Recommend
        let recommendation = engine.recommend(
            for: "model",
            currentProjection: projection,
            availableScopes: [.user, .project, .managed]
        )

        // Assert: not editable, has lock info
        XCTAssertFalse(recommendation.isEditable)
        XCTAssertNotNil(recommendation.lockInfo)
        XCTAssertEqual(recommendation.lockInfo?.controllingTier, .fileBased)
        XCTAssertEqual(recommendation.lockInfo?.sourcePath, "/etc/claude/managed.json")
    }

    func testExistingUserScopeKeyRecommendsUser() {
        // Build a projection with a key already at user scope
        let userSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-settings",
            displayName: "User settings",
            sourcePath: "~/.claude/settings.json",
            availability: .present
        )

        let trace = ResolutionTrace(
            participants: [userSource],
            overridden: []
        )

        let entry = ResolvedSettingsEntry(
            keyPath: "temperature",
            value: ResolvedValue(
                effectiveValue: .number(0.7),
                winningSource: userSource,
                trace: trace,
                mergeMethod: .selectHighestPrecedence
            )
        )

        let settings = ResolvedSettingsSnapshot(entries: [entry])
        let projection = SessionProjection(settings: settings)

        // Recommend
        let recommendation = engine.recommend(
            for: "temperature",
            currentProjection: projection,
            availableScopes: [.user, .project]
        )

        // Assert: recommends user scope
        XCTAssertEqual(recommendation.recommendedScope, .user)
        XCTAssertTrue(recommendation.isEditable)
        XCTAssertNil(recommendation.lockInfo)
    }

    func testPersonalPreferenceKeyRecommendsUser() {
        // Empty projection (key not yet defined)
        let projection = SessionProjection(settings: ResolvedSettingsSnapshot(entries: []))

        // Recommend for a personal preference key
        let recommendation = engine.recommend(
            for: "verbose",
            currentProjection: projection,
            availableScopes: [.user, .project]
        )

        // Assert: recommends user scope for personal preference
        XCTAssertEqual(recommendation.recommendedScope, .user)
        XCTAssertTrue(recommendation.isEditable)
        XCTAssertNil(recommendation.lockInfo)
        XCTAssert(recommendation.rationale.contains("personal preference"))
    }

    func testProjectBehaviourKeyRecommendsProject() {
        // Empty projection (key not yet defined)
        let projection = SessionProjection(settings: ResolvedSettingsSnapshot(entries: []))

        // Recommend for a project behaviour key
        let recommendation = engine.recommend(
            for: "permissions.allow.0",
            currentProjection: projection,
            availableScopes: [.user, .project]
        )

        // Assert: recommends project scope for project behaviour
        XCTAssertEqual(recommendation.recommendedScope, .project)
        XCTAssertTrue(recommendation.isEditable)
        XCTAssertNil(recommendation.lockInfo)
        XCTAssert(recommendation.rationale.contains("project"))
    }
}
