import XCTest
@testable import ClaudeConfigManager

/// Packet 15 tests — Resolution trace panel logic.
@MainActor
final class ResolutionTracePanelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSource(
        scope: ResolutionScope,
        identifier: String = "settings.json",
        displayName: String? = nil,
        sourcePath: String? = nil
    ) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: identifier,
            displayName: displayName,
            sourcePath: sourcePath
        )
    }

    private func makeEntry(
        keyPath: String,
        effectiveValue: JSONValue?,
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

    // MARK: - Tests

    func testPanelShowsWinningValue() {
        let winner = makeSource(scope: .managed, identifier: "managed-settings", sourcePath: "/managed/settings.json")
        let entry = makeEntry(
            keyPath: "apiKey",
            effectiveValue: .string("prod-key"),
            winningSource: winner,
            participants: [winner]
        )

        let rows = ResolutionTracePanelView.buildScopeRows(from: entry.value)

        XCTAssertEqual(rows.count, 1, "Should have one scope row for the single participant")
        XCTAssertEqual(rows[0].scope, .managed)
        XCTAssertEqual(rows[0].participation, .winning, "The only participant should be the winner")

        // Verify the entry carries the effective value
        XCTAssertEqual(entry.value.effectiveValue, .string("prod-key"))
        XCTAssertEqual(entry.value.winningSource?.scope, .managed)
    }

    func testOverriddenScopesHaveCorrectParticipation() {
        let winner = makeSource(scope: .managed, identifier: "managed-settings", displayName: "managed-val", sourcePath: "/managed/settings.json")
        let loser = makeSource(scope: .user, identifier: "user-settings", displayName: "user-val", sourcePath: "/user/settings.json")

        let entry = makeEntry(
            keyPath: "model",
            effectiveValue: .string("claude-3"),
            winningSource: winner,
            participants: [winner, loser],
            overridden: [loser],
            mergeMethod: .selectHighestPrecedence
        )

        let rows = ResolutionTracePanelView.buildScopeRows(from: entry.value)

        XCTAssertEqual(rows.count, 2, "Should have rows for managed (winner) and user (overridden)")

        let managedRow = rows.first { $0.scope == .managed }
        let userRow = rows.first { $0.scope == .user }

        XCTAssertNotNil(managedRow)
        XCTAssertNotNil(userRow)
        XCTAssertEqual(managedRow?.participation, .winning)
        XCTAssertEqual(userRow?.participation, .overridden, "Overridden scope should have .overridden participation")
    }

    func testArrayMergeShowsAllContributors() {
        let managedSource = makeSource(scope: .managed, identifier: "managed-settings", displayName: "deny-managed", sourcePath: "/managed/settings.json")
        let userSource = makeSource(scope: .user, identifier: "user-settings", displayName: "deny-user", sourcePath: "/user/settings.json")

        let entry = makeEntry(
            keyPath: "permissions.deny",
            effectiveValue: .array([.string("rm -rf"), .string("sudo")]),
            winningSource: managedSource,
            participants: [managedSource, userSource],
            overridden: [],
            mergeMethod: .appendUnique
        )

        let rows = ResolutionTracePanelView.buildScopeRows(from: entry.value)

        XCTAssertEqual(rows.count, 2, "Should have rows for both contributing scopes")

        let managedRow = rows.first { $0.scope == .managed }
        let userRow = rows.first { $0.scope == .user }

        XCTAssertNotNil(managedRow)
        XCTAssertNotNil(userRow)

        // For merge methods, non-overridden participants should be .winning or .merged
        XCTAssertEqual(managedRow?.participation, .winning, "Winning source should be .winning even in merge")
        XCTAssertEqual(userRow?.participation, .merged, "Non-winning contributor in merge should be .merged")
    }

    func testAbsentScopesAreNotShown() {
        // Only the participating scopes should appear — absent scopes are excluded
        // unless they are between participating scopes in the precedence order.
        let winner = makeSource(scope: .user, identifier: "user-settings", sourcePath: "/user/settings.json")

        let entry = makeEntry(
            keyPath: "theme",
            effectiveValue: .string("dark"),
            winningSource: winner,
            participants: [winner]
        )

        let rows = ResolutionTracePanelView.buildScopeRows(from: entry.value)

        // Only the user scope should appear (not managed, project, session, etc.)
        XCTAssertEqual(rows.count, 1, "Should only show participating scopes")
        XCTAssertEqual(rows[0].scope, .user)
        XCTAssertEqual(rows[0].participation, .winning)

        // Verify that .managed, .project, .session are not in the rows
        let scopes = Set(rows.map(\.scope))
        XCTAssertFalse(scopes.contains(.managed), "Absent managed scope should not appear")
        XCTAssertFalse(scopes.contains(.project), "Absent project scope should not appear")
        XCTAssertFalse(scopes.contains(.session), "Absent session scope should not appear")
    }

    func testScopeOrderFollowsPrecedence() {
        // Scopes should appear in precedence order: managed before user before project
        let managedSource = makeSource(scope: .managed, identifier: "m", displayName: "m-val")
        let userSource = makeSource(scope: .user, identifier: "u", displayName: "u-val")
        let projectSource = makeSource(scope: .project, identifier: "p", displayName: "p-val")

        let entry = makeEntry(
            keyPath: "key",
            effectiveValue: .string("val"),
            winningSource: managedSource,
            participants: [userSource, projectSource, managedSource], // deliberately out of order
            overridden: [userSource, projectSource],
            mergeMethod: .selectHighestPrecedence
        )

        let rows = ResolutionTracePanelView.buildScopeRows(from: entry.value)
        let scopes = rows.map(\.scope)

        // managed < user < project in precedence (managed is highest)
        XCTAssertEqual(scopes, [.managed, .project, .user],
                       "Scopes should be in canonical precedence order")
    }
}
