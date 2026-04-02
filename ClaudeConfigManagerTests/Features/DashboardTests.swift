import XCTest
@testable import ClaudeConfigManager

/// Packet 16 tests — Configuration Dashboard logic.
final class DashboardTests: XCTestCase {

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

    // MARK: - testDashboardHealthSummaryCounts

    func testDashboardHealthSummaryCounts() {
        // Build a projection with known issue counts
        let userSource = makeSource(scope: .user)
        let managedSource = makeSource(scope: .managed)

        let entry1 = makeEntry(
            keyPath: "disableAutoUpdates",
            effectiveValue: .bool(true),
            winningSource: managedSource,
            participants: [managedSource],
            overridden: [userSource]
        )
        let entry2 = makeEntry(
            keyPath: "theme",
            effectiveValue: .string("dark"),
            winningSource: userSource,
            participants: [userSource]
        )

        let projection = makeProjection(entries: [entry1, entry2])

        // Resolved settings count
        XCTAssertEqual(projection.settings?.entries.count, 2)

        // Issue summary defaults
        XCTAssertEqual(projection.issueSummary.errorCount, 0)
        XCTAssertEqual(projection.issueSummary.warningCount, 0)

        // Conflict detection: entry1 has 2 scopes (participant + overridden)
        let conflicts = DashboardDataHelpers.recentConflicts(from: projection, limit: 5)
        XCTAssertEqual(conflicts.count, 1, "Only entry1 has more than 1 scope with opinions")
        XCTAssertEqual(conflicts.first?.keyPath, "disableAutoUpdates")
    }

    // MARK: - testRecentConflictsSortedByParticipantCount

    func testRecentConflictsSortedByParticipantCount() {
        let managed = makeSource(scope: .managed)
        let user = makeSource(scope: .user)
        let project = makeSource(scope: .project)
        let cli = makeSource(scope: .cli)

        // Key A: 3 scopes had opinions (managed wins, user + project overridden)
        let keyA = makeEntry(
            keyPath: "keyA",
            effectiveValue: .bool(true),
            winningSource: managed,
            participants: [managed],
            overridden: [user, project]
        )

        // Key B: 1 scope (only user)
        let keyB = makeEntry(
            keyPath: "keyB",
            effectiveValue: .string("blue"),
            winningSource: user,
            participants: [user]
        )

        // Key C: 2 scopes (cli wins, managed overridden)
        let keyC = makeEntry(
            keyPath: "keyC",
            effectiveValue: .number(42),
            winningSource: cli,
            participants: [cli],
            overridden: [managed]
        )

        let projection = makeProjection(entries: [keyA, keyB, keyC])
        let conflicts = DashboardDataHelpers.recentConflicts(from: projection, limit: 5)

        // keyB has only 1 scope — excluded (filter requires > 1)
        // keyA has 3, keyC has 2 → order: keyA, keyC
        XCTAssertEqual(conflicts.count, 2)
        XCTAssertEqual(conflicts[0].keyPath, "keyA", "keyA (3 scopes) should come first")
        XCTAssertEqual(conflicts[1].keyPath, "keyC", "keyC (2 scopes) should come second")
    }

    // MARK: - testScopeContributionData

    func testScopeContributionDataWins() {
        let userSource = makeSource(scope: .user)
        let managedSource = makeSource(scope: .managed)

        let winEntry = makeEntry(
            keyPath: "theme",
            effectiveValue: .string("dark"),
            winningSource: userSource,
            participants: [userSource]
        )
        let loseEntry = makeEntry(
            keyPath: "disableAutoUpdates",
            effectiveValue: .bool(true),
            winningSource: managedSource,
            participants: [managedSource],
            overridden: [userSource]
        )

        let projection = makeProjection(entries: [winEntry, loseEntry])
        let data = ScopeContributionData.compute(from: projection, scope: .user)

        XCTAssertEqual(data.wins.count, 1)
        XCTAssertEqual(data.wins.first?.keyPath, "theme")

        XCTAssertEqual(data.losses.count, 1)
        XCTAssertEqual(data.losses.first?.keyPath, "disableAutoUpdates")

        XCTAssertEqual(data.contributions.count, 0)
    }

    func testScopeContributionDataMergeContribution() {
        let userSource = makeSource(scope: .user)
        let projectSource = makeSource(scope: .project)

        // Array-merge entry: project wins, user contributes
        let mergeEntry = makeEntry(
            keyPath: "allowedTools",
            effectiveValue: .array([.string("bash"), .string("edit")]),
            winningSource: projectSource,
            participants: [projectSource, userSource],
            overridden: [],
            mergeMethod: .appendUnique
        )

        let projection = makeProjection(entries: [mergeEntry])
        let userData = ScopeContributionData.compute(from: projection, scope: .user)

        XCTAssertEqual(userData.wins.count, 0, "User did not win")
        XCTAssertEqual(userData.contributions.count, 1, "User contributed to the merge")
        XCTAssertEqual(userData.contributions.first?.keyPath, "allowedTools")
    }
}
