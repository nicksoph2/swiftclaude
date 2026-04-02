import XCTest
@testable import ClaudeConfigManager

@MainActor
final class SubagentTreeViewModelTests: XCTestCase {

    // MARK: - Test: Subagent directory scanned — one child node

    func testSubagentDirectoryScanned() throws {
        let parentMetadata = makeMetadata(
            id: "parent-session",
            sessionId: "sess-parent",
            transcriptKind: .primarySession,
            agentId: nil,
            projectKey: "project-one",
            transcriptPath: "/tmp/.claude/projects/project-one/sess-parent.jsonl",
            lineCount: 5,
            totalTokensIn: 1000,
            totalTokensOut: 500
        )

        let subagentMetadata = makeMetadata(
            id: "subagent-child",
            sessionId: "sess-parent",
            transcriptKind: .subagent,
            agentId: "agent-abc123",
            projectKey: "project-one",
            transcriptPath: "/tmp/.claude/projects/project-one/sess-parent/subagents/agent-abc123.jsonl",
            lineCount: 3,
            totalTokensIn: 200,
            totalTokensOut: 80
        )

        let parentEntries = [
            makeEntry(lineNumber: 1, type: "human", role: "user", content: "Implement the login feature"),
            makeEntry(lineNumber: 2, type: "assistant", role: "assistant", content: "I'll implement login"),
        ]

        let subagentEntries = [
            makeEntry(lineNumber: 1, type: "human", role: "user", content: "Write unit tests for auth"),
            makeEntry(lineNumber: 2, type: "assistant", role: "assistant", content: "Writing tests"),
        ]

        let viewModel = SubagentTreeViewModel()
        viewModel.build(
            parentMetadata: parentMetadata,
            parentEntries: parentEntries,
            subagentMetadataList: [subagentMetadata],
            subagentEntriesByPath: [subagentMetadata.transcriptPath: subagentEntries]
        )

        XCTAssertTrue(viewModel.hasSubagents)
        XCTAssertNotNil(viewModel.rootNode)

        let root = try XCTUnwrap(viewModel.rootNode)
        XCTAssertTrue(root.isParent)
        XCTAssertEqual(root.sessionId, "sess-parent")
        XCTAssertEqual(root.inputTokens, 1000)
        XCTAssertEqual(root.outputTokens, 500)
        XCTAssertEqual(root.taskSummary, "Implement the login feature")

        XCTAssertEqual(root.children.count, 1)
        let child = root.children[0]
        XCTAssertFalse(child.isParent)
        XCTAssertEqual(child.agentId, "agent-abc123")
        XCTAssertEqual(child.inputTokens, 200)
        XCTAssertEqual(child.outputTokens, 80)
        XCTAssertEqual(child.taskSummary, "Write unit tests for auth")

        // Total tokens = parent (1500) + child (280)
        XCTAssertEqual(viewModel.totalTokensIncludingSubagents, 1780)
    }

    // MARK: - Test: No subagents shows hasSubagents = false

    func testNoSubagentsDoesNotShowSubagents() {
        let parentMetadata = makeMetadata(
            id: "parent-only",
            sessionId: "sess-solo",
            transcriptKind: .primarySession,
            agentId: nil,
            projectKey: "project-solo",
            transcriptPath: "/tmp/.claude/projects/project-solo/sess-solo.jsonl",
            lineCount: 3,
            totalTokensIn: 500,
            totalTokensOut: 200
        )

        let parentEntries = [
            makeEntry(lineNumber: 1, type: "human", role: "user", content: "Simple question"),
        ]

        let viewModel = SubagentTreeViewModel()
        viewModel.build(
            parentMetadata: parentMetadata,
            parentEntries: parentEntries,
            subagentMetadataList: [],
            subagentEntriesByPath: [:]
        )

        XCTAssertFalse(viewModel.hasSubagents)
        XCTAssertNotNil(viewModel.rootNode)
        XCTAssertEqual(viewModel.rootNode?.children.count, 0)
    }

    // MARK: - Test: Multiple subagents sorted by creation date

    func testMultipleSubagentsSortedByCreationDate() throws {
        let parentMetadata = makeMetadata(
            id: "parent",
            sessionId: "sess-multi",
            transcriptKind: .primarySession,
            agentId: nil,
            projectKey: "project-multi",
            transcriptPath: "/tmp/parent.jsonl",
            lineCount: 5,
            totalTokensIn: 2000,
            totalTokensOut: 1000
        )

        let sub1 = makeMetadata(
            id: "sub-1",
            sessionId: "sess-multi",
            transcriptKind: .subagent,
            agentId: "agent-first",
            projectKey: "project-multi",
            transcriptPath: "/tmp/sub1.jsonl",
            lineCount: 2,
            totalTokensIn: 100,
            totalTokensOut: 50,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let sub2 = makeMetadata(
            id: "sub-2",
            sessionId: "sess-multi",
            transcriptKind: .subagent,
            agentId: "agent-second",
            projectKey: "project-multi",
            transcriptPath: "/tmp/sub2.jsonl",
            lineCount: 2,
            totalTokensIn: 150,
            totalTokensOut: 70,
            createdAt: Date(timeIntervalSince1970: 100) // Earlier
        )

        let viewModel = SubagentTreeViewModel()
        viewModel.build(
            parentMetadata: parentMetadata,
            parentEntries: [],
            subagentMetadataList: [sub1, sub2],
            subagentEntriesByPath: [:]
        )

        let root = try XCTUnwrap(viewModel.rootNode)
        XCTAssertEqual(root.children.count, 2)
        // sub2 was created earlier, so it should come first
        XCTAssertEqual(root.children[0].agentId, "agent-second")
        XCTAssertEqual(root.children[1].agentId, "agent-first")

        // Total: parent (3000) + sub1 (150) + sub2 (220)
        XCTAssertEqual(viewModel.totalTokensIncludingSubagents, 3370)
    }

    // MARK: - Test: Task summary truncation

    func testTaskSummaryTruncatesLongContent() throws {
        let parentMetadata = makeMetadata(
            id: "parent",
            sessionId: "sess-long",
            transcriptKind: .primarySession,
            agentId: nil,
            projectKey: "project",
            transcriptPath: "/tmp/parent.jsonl",
            lineCount: 2,
            totalTokensIn: 100,
            totalTokensOut: 50
        )

        let longMessage = String(repeating: "A very long message ", count: 20)
        let parentEntries = [
            makeEntry(lineNumber: 1, type: "human", role: "user", content: longMessage),
        ]

        let viewModel = SubagentTreeViewModel()
        viewModel.build(
            parentMetadata: parentMetadata,
            parentEntries: parentEntries,
            subagentMetadataList: [],
            subagentEntriesByPath: [:]
        )

        let root = try XCTUnwrap(viewModel.rootNode)
        XCTAssertTrue(root.taskSummary.count <= 124) // 120 chars + "..."
        XCTAssertTrue(root.taskSummary.hasSuffix("..."))
    }

    // MARK: - Test: Default task summary when no user turn

    func testDefaultTaskSummaryWhenNoUserTurn() throws {
        let parentMetadata = makeMetadata(
            id: "parent",
            sessionId: "sess-nouser",
            transcriptKind: .primarySession,
            agentId: nil,
            projectKey: "project",
            transcriptPath: "/tmp/parent.jsonl",
            lineCount: 1,
            totalTokensIn: 50,
            totalTokensOut: 20
        )

        let entries = [
            makeEntry(lineNumber: 1, type: "assistant", role: "assistant", content: "Ready to help"),
        ]

        let viewModel = SubagentTreeViewModel()
        viewModel.build(
            parentMetadata: parentMetadata,
            parentEntries: entries,
            subagentMetadataList: [],
            subagentEntriesByPath: [:]
        )

        let root = try XCTUnwrap(viewModel.rootNode)
        XCTAssertEqual(root.taskSummary, "Session")
    }

    // MARK: - Helpers

    private func makeMetadata(
        id: String,
        sessionId: String?,
        transcriptKind: TranscriptKind,
        agentId: String?,
        projectKey: String?,
        transcriptPath: String,
        lineCount: Int,
        totalTokensIn: Int?,
        totalTokensOut: Int?,
        createdAt: Date? = nil
    ) -> TranscriptMetadata {
        TranscriptMetadata(
            id: id,
            sessionId: sessionId,
            transcriptKind: transcriptKind,
            agentId: agentId,
            projectKey: projectKey,
            transcriptPath: transcriptPath,
            fileSize: Int64(lineCount * 200),
            createdAt: createdAt,
            modifiedAt: Date(timeIntervalSince1970: 100),
            lineCount: lineCount,
            model: "claude-sonnet-4-6",
            totalTokensIn: totalTokensIn,
            totalTokensOut: totalTokensOut
        )
    }

    private func makeEntry(
        lineNumber: Int,
        type: String?,
        role: String?,
        content: String?
    ) -> TranscriptEntry {
        TranscriptEntry(
            lineNumber: lineNumber,
            rawJson: [:],
            rawLine: "",
            type: type,
            role: role,
            contentPreview: content,
            model: nil,
            timestamp: nil,
            usage: nil
        )
    }
}
