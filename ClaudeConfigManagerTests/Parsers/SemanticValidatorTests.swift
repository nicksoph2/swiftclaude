import XCTest
@testable import ClaudeConfigManager

final class SemanticValidatorTests: XCTestCase {
    private let validator = SemanticProjectionValidator()

    // MARK: - Test: Deny Rule Shadows Allow Rule

    func testDenyRuleShadowsAllow() {
        let settings = createSettingsSnapshot(
            permissions: [
                "deny": .array([.string("bash:*")]),
                "allow": .array([.string("bash: ls")])
            ]
        )

        let projection = SessionProjection(settings: settings)
        let issues = validator.validate(projection)

        let shadowIssues = issues.filter { $0.code.rawValue.contains("denyRuleShadow") }
        XCTAssertFalse(shadowIssues.isEmpty, "Expected deny rule shadow warning")
        XCTAssertTrue(shadowIssues.allSatisfy { $0.severity == .warning })
    }

    // MARK: - Test: Instruction Token Budget Exceeded

    func testInstructionBudgetExceeded() {
        let largeContent = String(repeating: "a", count: 200_000)

        let source = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "CLAUDE.md",
            displayName: "CLAUDE.md",
            sourcePath: "/path/to/CLAUDE.md"
        )

        let instructions = createInstructionSnapshot(
            blocks: [
                ResolvedInstructionBlock(
                    blockID: "test",
                    content: ResolvedValue(
                        effectiveValue: largeContent,
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [],
                        notes: []
                    )
                )
            ]
        )

        let projection = SessionProjection(instructions: instructions)
        let issues = validator.validate(projection)

        let budgetIssues = issues.filter { $0.code.rawValue.contains("tokenBudget") }
        XCTAssertFalse(budgetIssues.isEmpty, "Expected token budget exceeded warning")
        XCTAssertTrue(budgetIssues.allSatisfy { $0.severity == .warning })
    }

    // MARK: - Test: Redundant Permission Rules

    func testRedundantRule() {
        let settings = createSettingsSnapshot(
            permissions: [
                "deny": .array([.string("bash:*"), .string("bash:*")])
            ]
        )

        let projection = SessionProjection(settings: settings)
        let issues = validator.validate(projection)

        let redundantIssues = issues.filter { $0.code.rawValue.contains("redundant") }
        XCTAssertFalse(redundantIssues.isEmpty, "Expected redundant rule info")
        XCTAssertTrue(redundantIssues.allSatisfy { $0.severity == .info })
    }

    // MARK: - Test: Clean Projection Emits No Issues

    func testCleanProjectionEmitsNoIssues() {
        let settings = createSettingsSnapshot(
            permissions: [
                "allow": .array([.string("bash: ls"), .string("Read(./**)")]),
                "deny": .array([.string("Bash(rm -rf /)")])
            ]
        )

        let projection = SessionProjection(settings: settings)
        let issues = validator.validate(projection)

        XCTAssertTrue(issues.isEmpty, "Expected no issues for clean projection")
    }

    // MARK: - Helper Methods

    private func createSettingsSnapshot(
        permissions: [String: JSONValue]? = nil
    ) -> ResolvedSettingsSnapshot {
        var entries: [ResolvedSettingsEntry] = []

        if let permissions = permissions {
            let source = ResolutionSource(
                scope: .user,
                kind: .file,
                identifier: "settings.json",
                displayName: "settings.json",
                sourcePath: "/path/to/settings.json"
            )

            entries.append(ResolvedSettingsEntry(
                keyPath: "permissions",
                value: ResolvedValue(
                    effectiveValue: .object(permissions),
                    winningSource: source,
                    trace: ResolutionTrace(participants: [source]),
                    mergeMethod: .selectHighestPrecedence,
                    issues: [],
                    notes: []
                )
            ))
        }

        return ResolvedSettingsSnapshot(
            entries: entries,
            issues: [],
            notes: []
        )
    }

    private func createInstructionSnapshot(
        blocks: [ResolvedInstructionBlock]
    ) -> ResolvedInstructionSnapshot {
        let source = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "CLAUDE.md",
            displayName: "CLAUDE.md",
            sourcePath: "/path/to/CLAUDE.md"
        )

        return ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "test",
                winningSource: source,
                trace: ResolutionTrace(participants: [source]),
                mergeMethod: .selectHighestPrecedence,
                issues: [],
                notes: []
            ),
            orderedBlocks: blocks,
            issues: [],
            notes: []
        )
    }
}
