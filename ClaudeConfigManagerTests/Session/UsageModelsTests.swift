import XCTest
@testable import ClaudeConfigManager

final class UsageModelsTests: XCTestCase {

    // MARK: - UsageAggregate Tests

    func testTotalTokensComputed() {
        let agg = makeAggregate(tokensIn: 500, tokensOut: 200)
        XCTAssertEqual(agg.totalTokens, 700)
    }

    func testTotalTokensZeroWhenBothZero() {
        let agg = makeAggregate(tokensIn: 0, tokensOut: 0)
        XCTAssertEqual(agg.totalTokens, 0)
    }

    func testTokensPerMinuteComputed() {
        let agg = makeAggregate(tokensIn: 500, tokensOut: 200, duration: 120) // 2 minutes
        let tpm = try! XCTUnwrap(agg.tokensPerMinute)
        XCTAssertEqual(tpm, 350.0, accuracy: 0.001)
    }

    func testTokensPerMinuteNilWhenDurationNil() {
        let agg = makeAggregate(tokensIn: 500, tokensOut: 200, duration: nil)
        XCTAssertNil(agg.tokensPerMinute)
    }

    func testTokensPerMinuteNilWhenDurationZero() {
        let agg = makeAggregate(tokensIn: 500, tokensOut: 200, duration: 0)
        XCTAssertNil(agg.tokensPerMinute)
    }

    func testCostPerKTokensComputed() {
        let agg = makeAggregate(tokensIn: 500, tokensOut: 500, costUsd: 0.10)
        // costPerKTokens = (0.10 * 1000) / 1000 = 0.10
        XCTAssertEqual(agg.costPerKTokens, 0.10, accuracy: 0.0001)
    }

    func testCostPerKTokensZeroWhenNoTokens() {
        let agg = makeAggregate(tokensIn: 0, tokensOut: 0, costUsd: 0.10)
        XCTAssertEqual(agg.costPerKTokens, 0.0, accuracy: 0.0001)
    }

    func testCostPerKTokensZeroWhenNoCost() {
        let agg = makeAggregate(tokensIn: 500, tokensOut: 500, costUsd: 0.0)
        XCTAssertEqual(agg.costPerKTokens, 0.0, accuracy: 0.0001)
    }

    // MARK: - ModelUsageBreakdown Tests

    func testModelBreakdownTotalTokens() {
        let breakdown = ModelUsageBreakdown(
            id: "claude-opus-4-6",
            model: "claude-opus-4-6",
            tokensIn: 300,
            tokensOut: 150,
            costUsd: 0.03,
            messageCount: 5
        )
        XCTAssertEqual(breakdown.totalTokens, 450)
    }

    // MARK: - PromptHistoryEntry Tests

    func testIsUserPrompt() {
        let entry = makePrompt(role: "user")
        XCTAssertTrue(entry.isUserPrompt)
        XCTAssertFalse(entry.isAssistantResponse)
    }

    func testIsAssistantResponse() {
        let entry = makePrompt(role: "assistant")
        XCTAssertFalse(entry.isUserPrompt)
        XCTAssertTrue(entry.isAssistantResponse)
    }

    func testFromTranscriptEntryUser() {
        let transcriptEntry = TranscriptEntry(
            lineNumber: 1,
            rawJson: [:],
            rawLine: "{}",
            type: nil,
            role: "user",
            contentPreview: "Hello, world!",
            model: nil,
            timestamp: Date(timeIntervalSince1970: 1_743_374_415),
            usage: nil
        )

        let prompt = PromptHistoryEntry.from(entry: transcriptEntry, sessionId: "sess-abc123")
        XCTAssertNotNil(prompt)
        XCTAssertEqual(prompt?.role, "user")
        XCTAssertEqual(prompt?.contentPreview, "Hello, world!")
        XCTAssertEqual(prompt?.contentFull, "Hello, world!")
        XCTAssertEqual(prompt?.sessionId, "sess-abc123")
        XCTAssertTrue(prompt?.isUserPrompt ?? false)
    }

    func testFromTranscriptEntryAssistant() {
        let transcriptEntry = TranscriptEntry(
            lineNumber: 2,
            rawJson: [:],
            rawLine: "{}",
            type: nil,
            role: "assistant",
            contentPreview: "Hello! How can I help you today?",
            model: nil,
            timestamp: Date(timeIntervalSince1970: 1_743_374_430),
            usage: TranscriptUsage(inputTokens: 10, outputTokens: 15)
        )

        let prompt = PromptHistoryEntry.from(entry: transcriptEntry, sessionId: "sess-abc123")
        XCTAssertNotNil(prompt)
        XCTAssertEqual(prompt?.role, "assistant")
        XCTAssertEqual(prompt?.tokensUsed, 25)
        XCTAssertTrue(prompt?.isAssistantResponse ?? false)
    }

    func testFromTranscriptEntryHumanMapsToUser() {
        let transcriptEntry = TranscriptEntry(
            lineNumber: 1,
            rawJson: [:],
            rawLine: "{}",
            type: "human",
            role: nil,
            contentPreview: "Test prompt",
            model: nil,
            timestamp: Date(timeIntervalSince1970: 1_743_374_400),
            usage: nil
        )

        let prompt = PromptHistoryEntry.from(entry: transcriptEntry, sessionId: "sess-123")
        XCTAssertNotNil(prompt)
        XCTAssertEqual(prompt?.role, "user")
    }

    func testFromTranscriptEntrySkipsToolUse() {
        let transcriptEntry = TranscriptEntry(
            lineNumber: 3,
            rawJson: [:],
            rawLine: "{}",
            type: "tool_use",
            role: nil,
            contentPreview: "Running command...",
            model: nil,
            timestamp: Date(timeIntervalSince1970: 1_743_374_445),
            usage: nil
        )

        let prompt = PromptHistoryEntry.from(entry: transcriptEntry, sessionId: "sess-123")
        XCTAssertNil(prompt)
    }

    func testContentPreviewTruncatesLongContent() {
        let longContent = String(repeating: "A", count: 300)
        let transcriptEntry = TranscriptEntry(
            lineNumber: 1,
            rawJson: [:],
            rawLine: "{}",
            type: nil,
            role: "user",
            contentPreview: longContent,
            model: nil,
            timestamp: Date(timeIntervalSince1970: 1_743_374_400),
            usage: nil
        )

        let prompt = PromptHistoryEntry.from(entry: transcriptEntry, sessionId: "sess-123")
        XCTAssertNotNil(prompt)
        XCTAssertEqual(prompt?.contentPreview.count, 200)
        XCTAssertEqual(prompt?.contentFull.count, 300)
    }

    func testZeroTokenUsageReturnsNil() {
        let transcriptEntry = TranscriptEntry(
            lineNumber: 1,
            rawJson: [:],
            rawLine: "{}",
            type: nil,
            role: "user",
            contentPreview: "Test",
            model: nil,
            timestamp: Date(timeIntervalSince1970: 1_743_374_400),
            usage: TranscriptUsage(inputTokens: 0, outputTokens: 0)
        )

        let prompt = PromptHistoryEntry.from(entry: transcriptEntry, sessionId: "sess-123")
        XCTAssertNotNil(prompt)
        XCTAssertNil(prompt?.tokensUsed)
    }

    // MARK: - UsageComputationError Tests

    func testErrorDescriptions() {
        XCTAssertNotNil(UsageComputationError.noSessionsFound.errorDescription)
        XCTAssertNotNil(UsageComputationError.invalidTokenCounts(sessionId: "s1", details: "negative").errorDescription)
        XCTAssertNotNil(UsageComputationError.failedToLoadTranscript(path: "/test").errorDescription)
        XCTAssertNotNil(UsageComputationError.internalError(details: "oops").errorDescription)
    }

    // MARK: - Codable Roundtrip Tests

    func testUsageAggregateRoundtrip() throws {
        let original = makeAggregate(tokensIn: 500, tokensOut: 200, costUsd: 0.05)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UsageAggregate.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testModelBreakdownRoundtrip() throws {
        let original = ModelUsageBreakdown(
            id: "claude-opus-4-6",
            model: "claude-opus-4-6",
            tokensIn: 500,
            tokensOut: 200,
            costUsd: 0.05,
            messageCount: 4
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelUsageBreakdown.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testPromptHistoryEntryRoundtrip() throws {
        let original = makePrompt(role: "user")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromptHistoryEntry.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Helpers

    private func makeAggregate(
        tokensIn: Int = 0,
        tokensOut: Int = 0,
        costUsd: Double = 0,
        duration: TimeInterval? = nil
    ) -> UsageAggregate {
        UsageAggregate(
            id: "sess-test",
            sessionId: "sess-test",
            startTime: Date(timeIntervalSince1970: 1_743_374_400),
            endTime: Date(timeIntervalSince1970: 1_743_374_400 + (duration ?? 0)),
            totalTokensIn: tokensIn,
            totalTokensOut: tokensOut,
            totalCostUsd: costUsd,
            modelUsage: [],
            messageCount: 0,
            toolUseCount: 0,
            duration: duration
        )
    }

    private func makePrompt(role: String) -> PromptHistoryEntry {
        PromptHistoryEntry(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
            sessionId: "sess-test",
            timestamp: Date(timeIntervalSince1970: 1_743_374_415),
            role: role,
            contentPreview: "Hello",
            contentFull: "Hello",
            tokensUsed: 5
        )
    }
}
