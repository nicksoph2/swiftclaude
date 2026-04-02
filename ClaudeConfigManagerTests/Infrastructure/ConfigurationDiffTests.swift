import XCTest
@testable import ClaudeConfigManager

final class ConfigurationDiffTests: XCTestCase {

    // MARK: - Helpers

    private func makeSnapshotEntry(
        keyPath: String,
        value: JSONValue?,
        scope: String = "user"
    ) -> SnapshotSettingsEntry {
        SnapshotSettingsEntry(
            keyPath: keyPath,
            resolvedValue: value,
            redacted: false,
            winningScope: scope,
            winningSourcePath: nil,
            provenance: []
        )
    }

    private func makeSnapshot(entries: [SnapshotSettingsEntry]) -> ConfigurationSnapshot {
        ConfigurationSnapshot(
            exportedAt: Date(),
            appVersion: "1.0.0",
            resolvedSettings: entries,
            resolvedInstructions: SnapshotInstructionsEntry(
                composedText: nil,
                blockCount: 0,
                winningScope: nil,
                winningSourcePath: nil
            ),
            mcpServers: [],
            permissionRules: SnapshotPermissionsEntry(permissionKeyCount: 0, entries: []),
            hooks: SnapshotHooksEntry(eventCount: 0, events: [])
        )
    }

    // MARK: - Diff Tests

    func testDiffDetectsAddedKey() {
        let snapshotA = makeSnapshot(entries: [
            makeSnapshotEntry(keyPath: "model", value: .string("claude-opus")),
        ])
        let snapshotB = makeSnapshot(entries: [
            makeSnapshotEntry(keyPath: "model", value: .string("claude-opus")),
            makeSnapshotEntry(keyPath: "verbose", value: .bool(true)),
        ])

        let diff = ConfigurationDiffEngine.diffSnapshots(old: snapshotA, new: snapshotB)

        let addedEntries = diff.filter { $0.changeKind == .added }
        XCTAssertEqual(addedEntries.count, 1)
        XCTAssertEqual(addedEntries.first?.keyPath, "verbose")
        XCTAssertEqual(addedEntries.first?.newValue, .bool(true))
        XCTAssertNil(addedEntries.first?.oldValue)
    }

    func testDiffDetectsRemovedKey() {
        let snapshotA = makeSnapshot(entries: [
            makeSnapshotEntry(keyPath: "model", value: .string("claude-opus")),
            makeSnapshotEntry(keyPath: "verbose", value: .bool(true)),
        ])
        let snapshotB = makeSnapshot(entries: [
            makeSnapshotEntry(keyPath: "model", value: .string("claude-opus")),
        ])

        let diff = ConfigurationDiffEngine.diffSnapshots(old: snapshotA, new: snapshotB)

        let removedEntries = diff.filter { $0.changeKind == .removed }
        XCTAssertEqual(removedEntries.count, 1)
        XCTAssertEqual(removedEntries.first?.keyPath, "verbose")
        XCTAssertEqual(removedEntries.first?.oldValue, .bool(true))
        XCTAssertNil(removedEntries.first?.newValue)
    }

    func testDiffDetectsChangedValue() {
        let snapshotA = makeSnapshot(entries: [
            makeSnapshotEntry(keyPath: "model", value: .string("claude-opus")),
            makeSnapshotEntry(keyPath: "maxTokens", value: .number(4096)),
        ])
        let snapshotB = makeSnapshot(entries: [
            makeSnapshotEntry(keyPath: "model", value: .string("claude-sonnet")),
            makeSnapshotEntry(keyPath: "maxTokens", value: .number(4096)),
        ])

        let diff = ConfigurationDiffEngine.diffSnapshots(old: snapshotA, new: snapshotB)

        let changedEntries = diff.filter { $0.changeKind == .changed }
        XCTAssertEqual(changedEntries.count, 1)
        XCTAssertEqual(changedEntries.first?.keyPath, "model")
        XCTAssertEqual(changedEntries.first?.oldValue, .string("claude-opus"))
        XCTAssertEqual(changedEntries.first?.newValue, .string("claude-sonnet"))

        let unchangedEntries = diff.filter { $0.changeKind == .unchanged }
        XCTAssertEqual(unchangedEntries.count, 1)
        XCTAssertEqual(unchangedEntries.first?.keyPath, "maxTokens")
    }

    func testDiffBothEmpty() {
        let snapshotA = makeSnapshot(entries: [])
        let snapshotB = makeSnapshot(entries: [])

        let diff = ConfigurationDiffEngine.diffSnapshots(old: snapshotA, new: snapshotB)
        XCTAssertTrue(diff.isEmpty)
    }

    func testDiffProfileAgainstProjection() {
        let profile = ConfigurationProfile(
            name: "Saved Profile",
            scope: .user,
            settings: [
                "model": .string("claude-opus"),
                "oldSetting": .bool(false),
            ]
        )

        let source = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-settings"
        )
        let entries: [ResolvedSettingsEntry] = [
            ResolvedSettingsEntry(
                keyPath: "model",
                value: ResolvedValue(
                    effectiveValue: .string("claude-sonnet"),
                    winningSource: source,
                    trace: ResolutionTrace(participants: [source]),
                    mergeMethod: .selectHighestPrecedence
                )
            ),
            ResolvedSettingsEntry(
                keyPath: "newSetting",
                value: ResolvedValue(
                    effectiveValue: .bool(true),
                    winningSource: source,
                    trace: ResolutionTrace(participants: [source]),
                    mergeMethod: .selectHighestPrecedence
                )
            ),
        ]

        let settings = ResolvedSettingsSnapshot(entries: entries)
        let projection = SessionProjection(settings: settings)

        let diff = ConfigurationDiffEngine.diffProfileAgainstProjection(
            profile: profile,
            projection: projection
        )

        let changed = diff.filter { $0.changeKind == .changed }
        let added = diff.filter { $0.changeKind == .added }
        let removed = diff.filter { $0.changeKind == .removed }

        XCTAssertEqual(changed.count, 1)
        XCTAssertEqual(changed.first?.keyPath, "model")

        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.keyPath, "newSetting")

        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.keyPath, "oldSetting")
    }

    func testExportDiffAsMarkdown() {
        let entries = [
            ConfigurationDiffEntry(keyPath: "model", changeKind: .changed, oldValue: .string("opus"), newValue: .string("sonnet")),
            ConfigurationDiffEntry(keyPath: "verbose", changeKind: .added, oldValue: nil, newValue: .bool(true)),
            ConfigurationDiffEntry(keyPath: "legacy", changeKind: .removed, oldValue: .string("old"), newValue: nil),
        ]

        let markdown = ConfigurationDiffEngine.exportDiffAsMarkdown(entries, title: "Test Diff")

        XCTAssertTrue(markdown.contains("# Configuration Diff Report"))
        XCTAssertTrue(markdown.contains("**Test Diff**"))
        XCTAssertTrue(markdown.contains("Added: 1"))
        XCTAssertTrue(markdown.contains("Removed: 1"))
        XCTAssertTrue(markdown.contains("Changed: 1"))
        XCTAssertTrue(markdown.contains("`model`"))
        XCTAssertTrue(markdown.contains("`verbose`"))
        XCTAssertTrue(markdown.contains("`legacy`"))
    }
}
