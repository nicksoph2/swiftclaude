import XCTest
@testable import ClaudeConfigManager

final class PermissionRuleSimulatorTests: XCTestCase {

    private let simulator = PermissionRuleSimulator()

    // MARK: - Helpers

    private func makeSource(scope: ResolutionScope) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: "\(scope.rawValue)-settings",
            displayName: "\(scope.rawValue) settings",
            sourcePath: "/mock/\(scope.rawValue)/settings.json"
        )
    }

    private func makeTrace(scope: ResolutionScope) -> ResolutionTrace {
        ResolutionTrace(participants: [makeSource(scope: scope)])
    }

    private func makeSettingsEntry(
        keyPath: String,
        patterns: [String],
        scope: ResolutionScope
    ) -> ResolvedSettingsEntry {
        let source = makeSource(scope: scope)
        let jsonPatterns: [JSONValue] = patterns.map { .string($0) }
        return ResolvedSettingsEntry(
            keyPath: keyPath,
            value: ResolvedValue(
                effectiveValue: .array(jsonPatterns),
                winningSource: source,
                trace: makeTrace(scope: scope),
                mergeMethod: .selectHighestPrecedence
            )
        )
    }

    private func makeProjection(
        denyPatterns: [String] = [],
        denyScope: ResolutionScope = .user,
        askPatterns: [String] = [],
        askScope: ResolutionScope = .user,
        allowPatterns: [String] = [],
        allowScope: ResolutionScope = .user,
        hooks: ResolvedHookSnapshot? = nil
    ) -> SessionProjection {
        var entries: [ResolvedSettingsEntry] = []

        if !denyPatterns.isEmpty {
            entries.append(makeSettingsEntry(keyPath: "permissions.deny", patterns: denyPatterns, scope: denyScope))
        }
        if !askPatterns.isEmpty {
            entries.append(makeSettingsEntry(keyPath: "permissions.ask", patterns: askPatterns, scope: askScope))
        }
        if !allowPatterns.isEmpty {
            entries.append(makeSettingsEntry(keyPath: "permissions.allow", patterns: allowPatterns, scope: allowScope))
        }

        let settings = ResolvedSettingsSnapshot(entries: entries)

        return SessionProjection(
            settings: settings,
            hooks: hooks
        )
    }

    // MARK: - Tests

    func testDenyRuleMatchesCorrectly() {
        let projection = makeProjection(denyPatterns: ["bash:*"])
        let result = simulator.evaluate(toolInvocation: "bash: rm -rf /tmp", against: projection)

        XCTAssertEqual(result.outcome, .blocked(by: "bash:*"))
        XCTAssertEqual(result.matchedRule, "bash:*")
        XCTAssertEqual(result.matchedAt, .deny)
    }

    func testAskRuleMatchesAfterNoDeny() {
        let projection = makeProjection(askPatterns: ["bash:*"])
        let result = simulator.evaluate(toolInvocation: "bash: git status", against: projection)

        XCTAssertEqual(result.outcome, .askUser(by: "bash:*"))
        XCTAssertEqual(result.matchedRule, "bash:*")
        XCTAssertEqual(result.matchedAt, .ask)
    }

    func testAllowRuleMatchesAfterNoAskOrDeny() {
        let projection = makeProjection(allowPatterns: ["bash:*"])
        let result = simulator.evaluate(toolInvocation: "bash: echo hello", against: projection)

        XCTAssertEqual(result.outcome, .allowed(by: "bash:*"))
        XCTAssertEqual(result.matchedRule, "bash:*")
        XCTAssertEqual(result.matchedAt, .allow)
    }

    func testNoRuleMatchesDefaultAsk() {
        let projection = makeProjection()
        let result = simulator.evaluate(toolInvocation: "bash: ls", against: projection)

        XCTAssertEqual(result.outcome, .askedByDefault)
        XCTAssertNil(result.matchedRule)
    }

    func testEvaluationTraceContainsAllSteps() {
        let projection = makeProjection(
            denyPatterns: ["read:*", "write:*"],
            askPatterns: ["bash:*"]
        )
        let result = simulator.evaluate(toolInvocation: "bash: git push", against: projection)

        // Should have 2 deny steps + 1 ask step = 3 total
        XCTAssertEqual(result.evaluationTrace.count, 3)

        // First two steps are deny gate
        XCTAssertEqual(result.evaluationTrace[0].gate, .deny)
        XCTAssertEqual(result.evaluationTrace[0].rule, "read:*")
        XCTAssertFalse(result.evaluationTrace[0].matched)

        XCTAssertEqual(result.evaluationTrace[1].gate, .deny)
        XCTAssertEqual(result.evaluationTrace[1].rule, "write:*")
        XCTAssertFalse(result.evaluationTrace[1].matched)

        // Third step is ask gate — matches
        XCTAssertEqual(result.evaluationTrace[2].gate, .ask)
        XCTAssertEqual(result.evaluationTrace[2].rule, "bash:*")
        XCTAssertTrue(result.evaluationTrace[2].matched)

        XCTAssertEqual(result.outcome, .askUser(by: "bash:*"))
    }

    func testHooksTriggeredForMatchingEvent() {
        let source = makeSource(scope: .user)
        let handler = ResolvedHookHandler(
            from: .object([
                "type": .string("command"),
                "command": .string("echo pre-hook fired")
            ]),
            source: source
        )

        let hookEvent = ResolvedHookEventEntry(
            eventID: "PreToolUse",
            eventType: .preToolUse,
            hooks: ResolvedValue(
                effectiveValue: [.object(["type": .string("command"), "command": .string("echo pre-hook fired")])],
                winningSource: source,
                trace: makeTrace(scope: .user),
                mergeMethod: .passthrough
            ),
            resolvedHandlers: [handler]
        )

        let hookSnapshot = ResolvedHookSnapshot(events: [hookEvent])
        let projection = makeProjection(hooks: hookSnapshot)

        let result = simulator.evaluate(toolInvocation: "bash: ls", against: projection)

        XCTAssertEqual(result.hooksTriggered.count, 1)
        XCTAssertEqual(result.hooksTriggered[0].event, "PreToolUse")
        XCTAssertEqual(result.hooksTriggered[0].handlerType, "command")
        XCTAssertTrue(result.hooksTriggered[0].handlerSummary.contains("echo pre-hook fired"))
    }

    // MARK: - Additional fnmatch tests

    func testExactMatchPattern() {
        let projection = makeProjection(denyPatterns: ["mcp__github__create_issue"])
        let result = simulator.evaluate(toolInvocation: "mcp__github__create_issue", against: projection)

        XCTAssertEqual(result.outcome, .blocked(by: "mcp__github__create_issue"))
    }

    func testWildcardSuffixPattern() {
        let projection = makeProjection(allowPatterns: ["mcp__github__*"])
        let result = simulator.evaluate(toolInvocation: "mcp__github__list_repos", against: projection)

        XCTAssertEqual(result.outcome, .allowed(by: "mcp__github__*"))
    }

    func testNonMatchingPatternFallsThrough() {
        let projection = makeProjection(denyPatterns: ["read:*"])
        let result = simulator.evaluate(toolInvocation: "bash: echo hello", against: projection)

        XCTAssertEqual(result.outcome, .askedByDefault)
    }

    func testDenyTakesPrecedenceOverAsk() {
        let projection = makeProjection(
            denyPatterns: ["bash:*"],
            askPatterns: ["bash:*"]
        )
        let result = simulator.evaluate(toolInvocation: "bash: rm -rf /", against: projection)

        XCTAssertEqual(result.outcome, .blocked(by: "bash:*"))
        XCTAssertEqual(result.matchedAt, .deny)
    }

    func testAskTakesPrecedenceOverAllow() {
        let projection = makeProjection(
            askPatterns: ["bash:*"],
            allowPatterns: ["bash:*"]
        )
        let result = simulator.evaluate(toolInvocation: "bash: ls", against: projection)

        XCTAssertEqual(result.outcome, .askUser(by: "bash:*"))
        XCTAssertEqual(result.matchedAt, .ask)
    }

    func testScopeIsReportedCorrectly() {
        let projection = makeProjection(
            denyPatterns: ["bash:*"],
            denyScope: .managed
        )
        let result = simulator.evaluate(toolInvocation: "bash: rm /", against: projection)

        XCTAssertEqual(result.matchedRuleScope, .managed)
    }
}
