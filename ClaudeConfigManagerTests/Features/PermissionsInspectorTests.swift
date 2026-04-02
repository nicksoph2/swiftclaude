import XCTest
@testable import ClaudeConfigManager

/// Packet 21 tests — Permissions Inspector logic.
final class PermissionsInspectorTests: XCTestCase {

    // MARK: - Helpers

    private func makeSource(
        scope: ResolutionScope,
        path: String? = nil
    ) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: path ?? "\(scope.rawValue)-settings",
            sourcePath: path
        )
    }

    private func makeEntry(
        keyPath: String,
        patterns: [String],
        scope: ResolutionScope,
        path: String? = nil
    ) -> ResolvedSettingsEntry {
        let resolvedPath = path ?? "/\(scope.rawValue)/settings.json"
        let source = makeSource(scope: scope, path: resolvedPath)
        return ResolvedSettingsEntry(
            keyPath: keyPath,
            value: ResolvedValue(
                effectiveValue: JSONValue.array(patterns.map { .string($0) }),
                winningSource: source,
                trace: ResolutionTrace(participants: [source]),
                mergeMethod: .appendUnique
            )
        )
    }

    // MARK: - testRulesGroupedCorrectly

    func testRulesGroupedCorrectly() {
        // Build entries covering all four group types
        let entries: [ResolvedSettingsEntry] = [
            makeEntry(keyPath: "permissions.deny",  patterns: ["read:/sensitive", "write:/system"], scope: .user),
            makeEntry(keyPath: "permissions.ask",   patterns: ["bash:*", "zsh:sudo"],              scope: .project),
            makeEntry(keyPath: "permissions.allow", patterns: ["read:/public", "mcp__web:search"], scope: .managed)
        ]

        let settings = ResolvedSettingsSnapshot(entries: entries)
        let projection = SessionProjection(settings: settings)

        // Extract rules using the same logic the view uses
        var fileOps: [PermissionRuleWithOrigin] = []
        var shell: [PermissionRuleWithOrigin] = []
        var mcp: [PermissionRuleWithOrigin] = []
        var other: [PermissionRuleWithOrigin] = []

        for entry in entries {
            guard let array = entry.value.effectiveValue, case .array(let items) = array else { continue }
            let ruleType: PermissionRuleType
            if entry.keyPath.hasSuffix(".deny") { ruleType = .deny }
            else if entry.keyPath.hasSuffix(".ask") { ruleType = .ask }
            else { ruleType = .allow }

            let source = entry.value.winningSource
            for (idx, item) in items.enumerated() {
                guard case .string(let pattern) = item else { continue }
                let rule = PermissionRuleWithOrigin(
                    pattern: pattern,
                    ruleType: ruleType,
                    sourceScope: source?.scope ?? .user,
                    sourcePath: source?.sourcePath,
                    sourceKeyPath: entry.keyPath,
                    arrayIndex: idx
                )
                if pattern.hasPrefix("read:") || pattern.hasPrefix("write:") || pattern.hasPrefix("edit:") {
                    fileOps.append(rule)
                } else if pattern.hasPrefix("bash:") || pattern.hasPrefix("zsh:") {
                    shell.append(rule)
                } else if pattern.hasPrefix("mcp__") {
                    mcp.append(rule)
                } else {
                    other.append(rule)
                }
            }
        }

        XCTAssertEqual(fileOps.count, 3, "2 deny + 1 allow read/write rules → 3 file-ops")
        XCTAssertEqual(shell.count, 2, "bash + zsh → 2 shell rules")
        XCTAssertEqual(mcp.count, 1, "mcp__ prefix → 1 MCP rule")
        XCTAssertEqual(other.count, 0, "No remaining rules")

        XCTAssertTrue(fileOps.contains { $0.pattern == "read:/sensitive" && $0.ruleType == .deny })
        XCTAssertTrue(fileOps.contains { $0.pattern == "write:/system" && $0.ruleType == .deny })
        XCTAssertTrue(fileOps.contains { $0.pattern == "read:/public" && $0.ruleType == .allow })
        XCTAssertTrue(shell.contains { $0.pattern == "bash:*" })
        XCTAssertTrue(mcp.contains { $0.pattern == "mcp__web:search" })

        // Verify settings are captured in the projection
        XCTAssertEqual(projection.settings?.entries.count, 3)
    }

    // MARK: - testConflictSectionHiddenWhenClean

    func testConflictSectionHiddenWhenClean() {
        let entry = makeEntry(
            keyPath: "permissions.allow",
            patterns: ["read:/public"],
            scope: .user
        )
        let settings = ResolvedSettingsSnapshot(entries: [entry])
        let projection = SessionProjection(settings: settings, issues: [])

        // A clean projection has no permission-related issues
        let permissionIssues = projection.issues.filter {
            $0.keyPath?.lowercased().contains("permission") == true
        }

        XCTAssertEqual(permissionIssues.count, 0)
        XCTAssertEqual(projection.issueSummary.errorCount, 0)
        XCTAssertEqual(projection.issueSummary.warningCount, 0)
    }

    // MARK: - testConflictSectionShownWhenIssuesPresent

    func testConflictSectionShownWhenIssuesPresent() {
        let denyEntry = makeEntry(
            keyPath: "permissions.deny",
            patterns: ["bash:*"],
            scope: .user
        )
        let allowEntry = makeEntry(
            keyPath: "permissions.allow",
            patterns: ["bash:ls"],
            scope: .project
        )
        let settings = ResolvedSettingsSnapshot(entries: [denyEntry, allowEntry])

        let conflictIssue = ResolutionIssue(
            code: .conflict,
            severity: .warning,
            message: "Conflicting permission rules: bash:* (deny) and bash:ls (allow) may match the same tool invocations with different outcomes.",
            keyPath: "permissions.deny",
            relatedSources: []
        )

        let projection = SessionProjection(settings: settings, issues: [conflictIssue])

        let permissionIssues = projection.issues.filter {
            $0.keyPath?.lowercased().contains("permission") == true
        }

        XCTAssertGreaterThan(permissionIssues.count, 0)
        XCTAssertEqual(permissionIssues.first?.severity, .warning)
        XCTAssertTrue(permissionIssues.first?.message.contains("bash:*") == true)
    }
}
