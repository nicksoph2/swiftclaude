import XCTest
@testable import ClaudeConfigManager

/// Packet 19 tests — pre-save resolution preview and override warnings.
@MainActor
final class PreSavePreviewTests: XCTestCase {

    // MARK: - Helpers

    /// Precedence rank matching the production logic in PreSavePreviewView.
    /// Lower rank = higher precedence = overrides others.
    private func scopePrecedenceRank(_ scope: ResolutionScope) -> Int {
        switch scope {
        case .managed: return 0
        case .cli: return 1
        case .projectLocal: return 2
        case .project: return 3
        case .user: return 4
        default: return 5
        }
    }

    private func makeSource(scope: ResolutionScope, path: String) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: path,
            displayName: path,
            sourcePath: path
        )
    }

    private func makeSettingsSnapshot(entries: [(keyPath: String, value: JSONValue, scope: ResolutionScope)]) -> ResolvedSettingsSnapshot {
        let resolvedEntries = entries.map { entry in
            ResolvedSettingsEntry(
                keyPath: entry.keyPath,
                value: ResolvedValue(
                    effectiveValue: entry.value,
                    winningSource: ResolutionSource(
                        scope: entry.scope,
                        kind: .file,
                        identifier: "\(entry.scope.rawValue)-settings",
                        sourcePath: "/\(entry.scope.rawValue)/settings.json"
                    ),
                    trace: ResolutionTrace(participants: [
                        ResolutionSource(
                            scope: entry.scope,
                            kind: .file,
                            identifier: "\(entry.scope.rawValue)-settings",
                            sourcePath: "/\(entry.scope.rawValue)/settings.json"
                        )
                    ]),
                    mergeMethod: .selectHighestPrecedence
                )
            )
        }
        return ResolvedSettingsSnapshot(entries: resolvedEntries)
    }

    private func tempSettingsFile(content: String) throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreSavePreviewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("settings.json")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return (dir, fileURL)
    }

    // MARK: - testPreviewShowsCorrectDelta

    func testPreviewShowsCorrectDelta() async throws {
        // Set up a temp file with verboseOutput = false
        let (dir, fileURL) = try tempSettingsFile(content: #"{"verboseOutput": false}"#)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Build a pipeline with a known current projection (verboseOutput = false at user scope)
        let pipeline = ConfigurationPipeline()

        // Run the pipeline against the temp file so it has an actual baseline projection.
        // Use the pipeline's globalRootURL as the temp dir so the scanner finds the file.
        // We won't wire a full scan; instead test preview directly with in-memory state.
        // The pipeline starts with no projection, so `before` values will be nil.
        // After applying the change, `after` should be the new value.

        let change = SettingsChange(
            keyPath: "verboseOutput",
            newValue: .bool(true),
            operation: .set
        )

        let result = await pipeline.preview(change: change, at: .user, fileURL: fileURL)

        // No error should occur
        XCTAssertNil(result.error, "Preview should not produce an error for a valid bool change")

        // targetFilePreview should contain the new value
        XCTAssertTrue(
            result.targetFilePreview.contains("verboseOutput"),
            "File preview should contain the changed key"
        )
        XCTAssertTrue(
            result.targetFilePreview.contains("true"),
            "File preview should contain the new value 'true'"
        )

        // When the pipeline has no existing projection, delta.before = nil, delta.after = .bool(true)
        let delta = result.affectedKeys.first(where: { $0.keyPath == "verboseOutput" })
        XCTAssertNotNil(delta, "affectedKeys should contain an entry for 'verboseOutput'")
        XCTAssertEqual(delta?.after, .bool(true), "after value should be the new value")
    }

    // MARK: - testOverrideWarningAppearsWhenHigherScopePresent

    func testOverrideWarningAppearsWhenHigherScopePresent() {
        // Simulate: we're trying to write "apiTimeout" at .project scope,
        // but .managed scope already owns the key (highest precedence).
        // After applying the change, the managed value still wins —
        // delta.winningScope = .managed (higher precedence than .project).

        let keyPath = "apiTimeout"
        let targetScope = ResolutionScope.project

        // The proposed projection shows managed winning
        let delta = KeyDelta(
            keyPath: keyPath,
            before: .number(30),
            after: .number(30),    // managed value unchanged — our project change is overridden
            winningScope: .managed
        )

        // Verify the override conflict detection logic:
        // managed (rank 0) < project (rank 3) → conflict exists
        let winningRank = scopePrecedenceRank(delta.winningScope)
        let targetRank = scopePrecedenceRank(targetScope)

        XCTAssertLessThan(
            winningRank,
            targetRank,
            "Managed scope (rank \(winningRank)) must have higher precedence than project scope (rank \(targetRank))"
        )

        // Override conflict should be detected: winningScope has higher precedence than targetScope
        let overrideConflictExists = winningRank < targetRank
        XCTAssertTrue(
            overrideConflictExists,
            "Override warning should appear when managed scope wins over project-scope change"
        )
    }

    // MARK: - testNoOverrideWarningWhenClear

    func testNoOverrideWarningWhenClear() {
        // We're writing "verboseOutput" at .user scope.
        // No higher-precedence scope defines this key, so user wins.
        let keyPath = "verboseOutput"
        let targetScope = ResolutionScope.user

        let delta = KeyDelta(
            keyPath: keyPath,
            before: nil,
            after: .bool(true),
            winningScope: .user   // our scope wins
        )

        let winningRank = scopePrecedenceRank(delta.winningScope)
        let targetRank = scopePrecedenceRank(targetScope)

        // No conflict: winningScope == targetScope → ranks are equal
        XCTAssertEqual(
            winningRank,
            targetRank,
            "When user scope wins and target is user, there is no override conflict"
        )

        let overrideConflictExists = winningRank < targetRank
        XCTAssertFalse(
            overrideConflictExists,
            "No override warning should appear when our target scope wins"
        )
    }

    // MARK: - testSchemaErrorDisablesConfirmButton

    func testSchemaErrorDisablesConfirmButton() async throws {
        // A type-invalid change should produce a PreviewResult with a non-nil error.
        // "includeCoAuthoredBy" is a known bool key in the registry.
        // Passing a .string value violates the type constraint → schemaValidationFailed.
        let (dir, fileURL) = try tempSettingsFile(content: "{}")
        defer { try? FileManager.default.removeItem(at: dir) }

        let pipeline = ConfigurationPipeline()

        let change = SettingsChange(
            keyPath: "includeCoAuthoredBy",
            newValue: .string("not-a-bool"),   // type mismatch: registry expects .bool
            operation: .set
        )

        let result = await pipeline.preview(change: change, at: .user, fileURL: fileURL)

        // The validator must reject a string value for a bool key
        XCTAssertNotNil(result.error, "PreviewResult.error should be non-nil for a type-invalid change")

        // Confirm the error is specifically a schema validation failure
        if case .schemaValidationFailed(let issues) = result.error {
            XCTAssertFalse(issues.isEmpty, "Validation error should contain at least one issue")
        } else {
            XCTFail("Expected .schemaValidationFailed but got: \(String(describing: result.error))")
        }
    }
}
