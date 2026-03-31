import XCTest
@testable import ClaudeConfigManager

@MainActor
final class RuntimeSessionDiscoveryTests: XCTestCase {
    func testParseStatusLinePayloadDecodesFullFixture() throws {
        let loader = FixtureLoader.shared
        let descriptor = try loader.descriptor(familyPath: "runtime/session_snapshot", caseID: "valid_statusline")
        let data = try Data(contentsOf: descriptor.inputFileURL(named: "statusline.json"))

        let discovery = RuntimeSessionDiscovery(nowProvider: { Date(timeIntervalSince1970: 1_738_000_000) })
        let result = discovery.parseStatusLinePayload(data)

        let snapshot = try XCTUnwrap(try result.get())
        XCTAssertEqual(snapshot.id, "sess-abc123def456")
        XCTAssertEqual(snapshot.modelId, "claude-opus-4-6")
        XCTAssertEqual(snapshot.modelDisplayName, "Opus")
        XCTAssertEqual(snapshot.cwd, "/Users/alice/projects/myproject")
        XCTAssertEqual(snapshot.projectDir, "/Users/alice/projects/myproject")
        XCTAssertEqual(try XCTUnwrap(snapshot.totalCostUsd), 0.87, accuracy: 0.0001)
        XCTAssertEqual(snapshot.totalInputTokens, 45_000)
        XCTAssertEqual(snapshot.totalOutputTokens, 12_000)
        XCTAssertEqual(try XCTUnwrap(snapshot.usedPercentage), 28.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.fiveHourUsedPercentage), 23.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.fiveHourResetsAt, 1_738_425_600)
        XCTAssertEqual(try XCTUnwrap(snapshot.sevenDayUsedPercentage), 41.2, accuracy: 0.001)
        XCTAssertEqual(snapshot.sevenDayResetsAt, 1_738_857_600)
        XCTAssertEqual(snapshot.totalTokens, 57_000)
    }

    func testParseStatusLinePayloadDecodesPartialFixtureWithNullCurrentUsage() throws {
        let loader = FixtureLoader.shared
        let descriptor = try loader.descriptor(familyPath: "runtime/session_snapshot", caseID: "partial_statusline")
        let data = try Data(contentsOf: descriptor.inputFileURL(named: "statusline.json"))

        let discovery = RuntimeSessionDiscovery()
        let result = discovery.parseStatusLinePayload(data)

        let snapshot = try XCTUnwrap(try result.get())
        XCTAssertEqual(snapshot.id, "sess-xyz789")
        XCTAssertEqual(snapshot.modelDisplayName, "Sonnet")
        XCTAssertEqual(snapshot.projectDir, nil)
        XCTAssertEqual(try XCTUnwrap(snapshot.totalCostUsd), 0.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.totalInputTokens, 0)
        XCTAssertEqual(snapshot.totalOutputTokens, 0)
        XCTAssertEqual(snapshot.contextWindowSize, 200_000)
        XCTAssertNil(snapshot.usedPercentage)
        XCTAssertNil(snapshot.fiveHourUsedPercentage)
    }

    func testStatusLinePayloadDecodesWorktreeFields() throws {
        let loader = FixtureLoader.shared
        let descriptor = try loader.descriptor(familyPath: "runtime/session_snapshot", caseID: "with_worktree")
        let data = try Data(contentsOf: descriptor.inputFileURL(named: "statusline.json"))

        let payload = try JSONDecoder().decode(StatusLinePayload.self, from: data)

        XCTAssertEqual(payload.worktree?.name, "my-feature")
        XCTAssertEqual(payload.worktree?.path, "/Users/alice/.claude/worktrees/my-feature")
        XCTAssertEqual(payload.worktree?.branch, "worktree-my-feature")
        XCTAssertEqual(payload.worktree?.originalCwd, "/Users/alice/projects/myproject")
        XCTAssertEqual(payload.worktree?.originalBranch, "main")
    }

    func testParseStatusLinePayloadMapsMissingRequiredField() {
        let json = """
        {
          "cwd": "/tmp",
          "transcript_path": "/tmp/session.jsonl",
          "model": { "id": "claude-sonnet-4-6", "display_name": "Sonnet" },
          "workspace": { "current_dir": "/tmp" },
          "cost": {},
          "context_window": {}
        }
        """

        let discovery = RuntimeSessionDiscovery()
        let result = discovery.parseStatusLinePayload(Data(json.utf8))

        guard case .failure(let error) = result else {
            return XCTFail("Expected decoding failure")
        }
        XCTAssertEqual(error, .missingRequiredField(fieldName: "session_id"))
    }

    func testDiscoverFromTranscriptsChoosesMostRecentPrimaryTranscript() async throws {
        let tempRoot = try makeTemporaryClaudeRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let projectRoot = tempRoot.appendingPathComponent("projects/example-project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let oldTranscript = projectRoot.appendingPathComponent("sess-old.jsonl", isDirectory: false)
        let newTranscript = projectRoot.appendingPathComponent("sess-new.jsonl", isDirectory: false)
        let subagentDirectory = projectRoot.appendingPathComponent("sess-new/subagents", isDirectory: true)
        try FileManager.default.createDirectory(at: subagentDirectory, withIntermediateDirectories: true)
        let subagentTranscript = subagentDirectory.appendingPathComponent("child.jsonl", isDirectory: false)

        try """
        {"event":"session_start","session_id":"sess-old","cwd":"/Users/test/old","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"}}
        """.write(to: oldTranscript, atomically: true, encoding: .utf8)

        try """
        {"event":"session_start","session_id":"sess-new","workspace":{"current_dir":"/Users/test/project","project_dir":"/Users/test/project"},"model":{"id":"claude-opus-4-6","display_name":"Opus"},"version":"1.0.80"}
        {"event":"assistant","message":{"model":"claude-opus-4-6"}}
        """.write(to: newTranscript, atomically: true, encoding: .utf8)

        try """
        {"event":"session_start","session_id":"child","workspace":{"current_dir":"/Users/test/subagent"},"model":{"id":"claude-haiku-4-5","display_name":"Haiku"}}
        """.write(to: subagentTranscript, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: oldTranscript.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newTranscript.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 300)], ofItemAtPath: subagentTranscript.path)

        let discovery = RuntimeSessionDiscovery(
            claudeRootURL: tempRoot,
            nowProvider: { Date(timeIntervalSince1970: 400) }
        )

        await discovery.discoverFromTranscripts()

        let snapshot = try XCTUnwrap(discovery.currentSession)
        XCTAssertEqual(discovery.dataSource, .transcriptDerived)
        XCTAssertEqual(snapshot.id, "sess-new")
        XCTAssertEqual(snapshot.modelId, "claude-opus-4-6")
        XCTAssertEqual(snapshot.modelDisplayName, "Opus")
        XCTAssertEqual(snapshot.cwd, "/Users/test/project")
        XCTAssertEqual(snapshot.projectDir, "/Users/test/project")
        XCTAssertEqual(snapshot.version, "1.0.80")
        XCTAssertEqual(snapshot.capturedAt, Date(timeIntervalSince1970: 200))
        XCTAssertTrue(discovery.discoveryIssues.isEmpty)
    }

    func testDiscoverFromTranscriptsLeavesEmptyStateWhenProjectsRootMissing() async throws {
        let tempRoot = try makeTemporaryClaudeRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let discovery = RuntimeSessionDiscovery(claudeRootURL: tempRoot)

        await discovery.discoverFromTranscripts()

        XCTAssertNil(discovery.currentSession)
        XCTAssertEqual(discovery.dataSource, .none)
        XCTAssertTrue(discovery.discoveryIssues.isEmpty)
        XCTAssertNotNil(discovery.lastUpdateTime)
    }

    func testRuntimeSessionSnapshotReportsStalenessAfterThirtyMinutes() {
        let capturedAt = Date.now.addingTimeInterval(-(31 * 60))
        let snapshot = RuntimeSessionSnapshot(
            id: "sess",
            transcriptPath: "/tmp/sess.jsonl",
            modelId: "claude-sonnet-4-6",
            modelDisplayName: "Sonnet",
            cwd: "/tmp",
            projectDir: nil,
            version: nil,
            totalCostUsd: nil,
            totalDurationMs: nil,
            totalLinesAdded: nil,
            totalLinesRemoved: nil,
            totalInputTokens: 100,
            totalOutputTokens: 50,
            contextWindowSize: nil,
            usedPercentage: nil,
            fiveHourUsedPercentage: nil,
            fiveHourResetsAt: nil,
            sevenDayUsedPercentage: nil,
            sevenDayResetsAt: nil,
            capturedAt: capturedAt
        )

        XCTAssertTrue(snapshot.isStale)
        XCTAssertEqual(snapshot.totalTokens, 150)
    }

    func testTranscriptScannerLoadsValidTranscriptFixture() async throws {
        let scanner = TranscriptScanner()
        let descriptor = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "valid_transcript")

        let (entries, issues) = await scanner.loadTranscriptContent(path: descriptor.inputFileURL(named: "transcript.jsonl").path)

        XCTAssertEqual(entries.count, 4)
        XCTAssertTrue(issues.isEmpty)
        XCTAssertEqual(entries[0].type, "human")
        XCTAssertEqual(entries[0].role, "user")
        XCTAssertEqual(entries[0].contentPreview, "Hello, world!")
        XCTAssertEqual(entries[1].model, "claude-opus-4-6")
        XCTAssertEqual(entries[1].usage?.inputTokens, 50)
        XCTAssertEqual(entries[1].usage?.outputTokens, 15)
    }

    func testTranscriptScannerPreservesMalformedLines() async throws {
        let scanner = TranscriptScanner()
        let descriptor = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "malformed_lines")

        let (entries, issues) = await scanner.loadTranscriptContent(path: descriptor.inputFileURL(named: "transcript.jsonl").path)

        XCTAssertEqual(entries.count, 4)
        XCTAssertGreaterThanOrEqual(issues.count, 1)
        XCTAssertEqual(entries.filter { $0.rawJson.isEmpty }.count, 2)
        XCTAssertEqual(entries[1].rawLine.trimmingCharacters(in: .whitespacesAndNewlines), "This is not JSON")
        XCTAssertFalse(entries[1].displayText.isEmpty)
    }

    func testTranscriptScannerPreservesUnknownRecordTypes() async throws {
        let scanner = TranscriptScanner()
        let descriptor = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "unknown_types")

        let (entries, issues) = await scanner.loadTranscriptContent(path: descriptor.inputFileURL(named: "transcript.jsonl").path)

        XCTAssertTrue(issues.isEmpty)
        XCTAssertEqual(entries[1].type, "some_future_record_type")
        XCTAssertEqual(entries[1].rawJson["data"]?.objectValue?["key"]?.stringValue, "value")
    }

    func testTranscriptScannerExtractsPrimaryMetadata() async throws {
        let tempRoot = try makeTemporaryClaudeRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let transcriptURL = tempRoot
            .appendingPathComponent("projects/project-one", isDirectory: true)
            .appendingPathComponent("sess-primary.jsonl", isDirectory: false)
        try FileManager.default.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let fixture = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "valid_transcript")
        try FileManager.default.copyItem(at: fixture.inputFileURL(named: "transcript.jsonl"), to: transcriptURL)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: transcriptURL.path)

        let scanner = TranscriptScanner(claudeRootURL: tempRoot)
        let (metadata, issues) = await scanner.extractMetadata(path: transcriptURL.path)

        let value = try XCTUnwrap(metadata)
        XCTAssertTrue(issues.isEmpty)
        XCTAssertEqual(value.sessionId, "sess-primary")
        XCTAssertEqual(value.transcriptKind, .primarySession)
        XCTAssertNil(value.agentId)
        XCTAssertEqual(value.projectKey, "project-one")
        XCTAssertEqual(value.lineCount, 4)
        XCTAssertEqual(value.model, "claude-opus-4-6")
        XCTAssertEqual(value.totalTokensIn, 50)
        XCTAssertEqual(value.totalTokensOut, 15)
        XCTAssertTrue(value.isRecent)
    }

    func testTranscriptScannerClassifiesSubagentTranscript() async throws {
        let tempRoot = try makeTemporaryClaudeRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let transcriptURL = tempRoot
            .appendingPathComponent("projects/project-two/sess-parent/subagents", isDirectory: true)
            .appendingPathComponent("agent-abc123.jsonl", isDirectory: false)
        try FileManager.default.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let fixture = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "subagent_transcript")
        try FileManager.default.copyItem(at: fixture.inputFileURL(named: "agent-abc123.jsonl"), to: transcriptURL)

        let scanner = TranscriptScanner(claudeRootURL: tempRoot)
        let (metadata, issues) = await scanner.extractMetadata(path: transcriptURL.path)

        let value = try XCTUnwrap(metadata)
        XCTAssertTrue(issues.isEmpty)
        XCTAssertEqual(value.transcriptKind, .subagent)
        XCTAssertEqual(value.sessionId, "sess-parent")
        XCTAssertEqual(value.agentId, "agent-abc123")
        XCTAssertEqual(value.projectKey, "project-two")
        XCTAssertEqual(value.lineCount, 2)
    }

    func testTranscriptScannerRecursesSortsAndKeepsSubagentsSeparate() async throws {
        let tempRoot = try makeTemporaryClaudeRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let projectOne = tempRoot.appendingPathComponent("projects/project-one", isDirectory: true)
        let projectTwo = tempRoot.appendingPathComponent("projects/project-two", isDirectory: true)
        try FileManager.default.createDirectory(at: projectOne, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectTwo, withIntermediateDirectories: true)

        let validFixture = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "valid_transcript")
        let unknownFixture = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "unknown_types")
        let subagentFixture = try FixtureLoader.shared.descriptor(familyPath: "runtime/transcripts", caseID: "subagent_transcript")

        let oldPrimary = projectOne.appendingPathComponent("sess-old.jsonl", isDirectory: false)
        let newPrimary = projectTwo.appendingPathComponent("sess-new.jsonl", isDirectory: false)
        let subagent = projectTwo
            .appendingPathComponent("sess-new/subagents", isDirectory: true)
            .appendingPathComponent("agent-abc123.jsonl", isDirectory: false)

        try FileManager.default.copyItem(at: validFixture.inputFileURL(named: "transcript.jsonl"), to: oldPrimary)
        try FileManager.default.copyItem(at: unknownFixture.inputFileURL(named: "transcript.jsonl"), to: newPrimary)
        try FileManager.default.createDirectory(at: subagent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: subagentFixture.inputFileURL(named: "agent-abc123.jsonl"), to: subagent)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: oldPrimary.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newPrimary.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 300)], ofItemAtPath: subagent.path)

        let scanner = TranscriptScanner(claudeRootURL: tempRoot)
        await scanner.scanTranscripts()

        XCTAssertEqual(scanner.recentTranscripts.map(\.sessionId), ["sess-new", "sess-old"])
        XCTAssertEqual(scanner.allTranscripts.count, 3)
        XCTAssertEqual(scanner.subagentTranscripts(forParentSessionID: "sess-new").count, 1)
        XCTAssertTrue(scanner.discoveryIssues.isEmpty)
    }

    func testTranscriptScannerHandlesEmptyTranscriptFiles() async throws {
        let tempRoot = try makeTemporaryClaudeRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let transcriptURL = tempRoot
            .appendingPathComponent("projects/project-empty", isDirectory: true)
            .appendingPathComponent("sess-empty.jsonl", isDirectory: false)
        try FileManager.default.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: transcriptURL)

        let scanner = TranscriptScanner(claudeRootURL: tempRoot)
        let (metadata, issues) = await scanner.extractMetadata(path: transcriptURL.path)

        let value = try XCTUnwrap(metadata)
        XCTAssertTrue(issues.isEmpty)
        XCTAssertEqual(value.lineCount, 0)
        XCTAssertNil(value.model)
        XCTAssertNil(value.totalTokensIn)
        XCTAssertNil(value.totalTokensOut)
    }

    private func makeTemporaryClaudeRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
