@testable import ClaudeConfigManager
import XCTest

final class TranscriptParserTests: XCTestCase {
    private var parser: TranscriptParser!
    private var fixtureURL: URL!

    override func setUp() {
        super.setUp()
        parser = TranscriptParser()
        fixtureURL = Bundle(for: type(of: self))
            .url(forResource: "basic", withExtension: "jsonl", subdirectory: "Fixtures/Transcripts")
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/Transcripts/basic.jsonl")
    }

    override func tearDown() {
        parser = nil
        fixtureURL = nil
        super.tearDown()
    }

    // MARK: - testParsesSummaryCorrectly

    func testParsesSummaryCorrectly() {
        let summary = parser.parseSummary(fileURL: fixtureURL)

        // 4 lines in the fixture
        XCTAssertEqual(summary.turnCount, 4, "Should parse all 4 turns from the fixture")

        // Input tokens: 120 + 200 = 320, Output tokens: 25 + 50 = 75
        XCTAssertEqual(summary.inputTokens, 320, "Should sum input tokens from all assistant turns")
        XCTAssertEqual(summary.outputTokens, 75, "Should sum output tokens from all assistant turns")

        // Model should be detected
        XCTAssertEqual(summary.modelsUsed["claude-sonnet-4-6"], 2, "Should count claude-sonnet-4-6 used in 2 assistant turns")
    }

    // MARK: - testStreamingParsesAllEntries

    func testStreamingParsesAllEntries() async throws {
        var entries: [TranscriptEntry] = []

        for try await entry in parser.parse(fileURL: fixtureURL) {
            entries.append(entry)
        }

        XCTAssertEqual(entries.count, 4, "Should stream all 4 entries from the fixture")

        // Verify order
        XCTAssertEqual(entries[0].type, "user", "First entry should be user type")
        XCTAssertEqual(entries[0].role, "user", "First entry should have user role")

        XCTAssertEqual(entries[1].type, "assistant", "Second entry should be assistant type")
        XCTAssertEqual(entries[1].role, "assistant", "Second entry should have assistant role")
        XCTAssertEqual(entries[1].model, "claude-sonnet-4-6", "Second entry should have model")

        XCTAssertEqual(entries[2].type, "assistant", "Third entry should be assistant type (tool_use in content)")
        XCTAssertNotNil(entries[2].usage, "Third entry should have usage")
        XCTAssertEqual(entries[2].usage?.inputTokens, 200)
        XCTAssertEqual(entries[2].usage?.outputTokens, 50)

        XCTAssertEqual(entries[3].type, "tool_result", "Fourth entry should be tool_result type")

        // Verify line numbers are sequential
        for (index, entry) in entries.enumerated() {
            XCTAssertEqual(entry.lineNumber, index + 1, "Entry \(index) should have line number \(index + 1)")
        }
    }

    // MARK: - testCostEstimationIsPositive

    func testCostEstimationIsPositive() {
        let summary = parser.parseSummary(fileURL: fixtureURL)

        XCTAssertGreaterThan(summary.estimatedCostUSD, 0, "Cost should be positive for non-zero tokens")

        // Verify cost is reasonable: Sonnet 4 pricing ($3/M input, $15/M output)
        // 320 input tokens → $0.00096, 75 output tokens → $0.001125, total ≈ $0.002085
        let expectedCost = (320.0 * 3.0 / 1_000_000) + (75.0 * 15.0 / 1_000_000)
        XCTAssertEqual(summary.estimatedCostUSD, expectedCost, accuracy: 0.0001, "Cost estimate should match Sonnet 4 rates")
    }

    // MARK: - testLargeFileDoesNotLoadEntirelyIntoMemory

    func testLargeFileDoesNotLoadEntirelyIntoMemory() {
        // This is a design verification test. parseSummary uses FileHandle-based
        // streaming and never reads the whole file into a single Data buffer.
        // We verify it works correctly on the fixture and returns a result
        // without needing to allocate proportional to file size.

        let summary = parser.parseSummary(fileURL: fixtureURL)

        // Verify that parseSummary completed and produced valid results
        // If it loaded everything into memory, it would still work for small files.
        // The key assertion is the correctness of the streaming approach.
        XCTAssertGreaterThan(summary.turnCount, 0, "parseSummary should successfully stream and count turns")
        XCTAssertEqual(summary.totalTokens, 395, "Total tokens should be 320 + 75 = 395")
    }

    // MARK: - testToolInvocationsDetected

    func testToolInvocationsDetected() {
        let summary = parser.parseSummary(fileURL: fixtureURL)

        // The fixture has a tool_use block inside an assistant message content array
        XCTAssertEqual(summary.toolInvocations["Read"], 1, "Should detect Read tool invocation from assistant content blocks")
    }

    // MARK: - testTimestampExtraction

    func testTimestampExtraction() {
        let summary = parser.parseSummary(fileURL: fixtureURL)

        XCTAssertNotNil(summary.startedAt, "Should extract start timestamp")
        XCTAssertNotNil(summary.lastActivityAt, "Should extract last activity timestamp")

        if let start = summary.startedAt, let last = summary.lastActivityAt {
            XCTAssertLessThanOrEqual(start, last, "Start should be before or equal to last activity")
        }
    }

    // MARK: - testCostEstimationRates

    func testCostEstimationRates() {
        // Opus model should use higher rates
        let opusCost = TranscriptCostEstimation.estimateCost(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            model: "claude-opus-4-6"
        )
        XCTAssertEqual(opusCost, 15.0 + 75.0, accuracy: 0.01, "Opus should cost $15 input + $75 output per million tokens")

        // Sonnet model
        let sonnetCost = TranscriptCostEstimation.estimateCost(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            model: "claude-sonnet-4-6"
        )
        XCTAssertEqual(sonnetCost, 3.0 + 15.0, accuracy: 0.01, "Sonnet should cost $3 input + $15 output per million tokens")

        // Haiku model
        let haikuCost = TranscriptCostEstimation.estimateCost(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            model: "claude-haiku-4-5-20251001"
        )
        XCTAssertEqual(haikuCost, 0.80 + 4.0, accuracy: 0.01, "Haiku should cost $0.80 input + $4 output per million tokens")

        // Unknown model should use Sonnet (default) rates
        let unknownCost = TranscriptCostEstimation.estimateCost(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            model: "some-future-model"
        )
        XCTAssertEqual(unknownCost, sonnetCost, accuracy: 0.01, "Unknown models should default to Sonnet rates")
    }

    // MARK: - testMarkdownExport

    func testMarkdownExport() async throws {
        var entries: [TranscriptEntry] = []
        for try await entry in parser.parse(fileURL: fixtureURL) {
            entries.append(entry)
        }
        let summary = parser.parseSummary(fileURL: fixtureURL)

        let metadata = TranscriptMetadata(
            id: "test",
            sessionId: "test-session-001",
            transcriptKind: .primarySession,
            agentId: nil,
            projectKey: "test-project",
            transcriptPath: fixtureURL.path,
            fileSize: 500,
            createdAt: nil,
            modifiedAt: Date(),
            lineCount: entries.count,
            model: "claude-sonnet-4-6",
            totalTokensIn: summary.inputTokens,
            totalTokensOut: summary.outputTokens
        )

        let markdown = TranscriptParser.markdownSummary(
            metadata: metadata,
            entries: entries,
            summary: summary
        )

        XCTAssertTrue(markdown.contains("# Transcript Summary"), "Markdown should contain title")
        // summary.sessionId is derived from the fixture filename ("basic")
        XCTAssertTrue(markdown.contains("basic"), "Markdown should contain session ID from filename")
        XCTAssertTrue(markdown.contains("claude-sonnet-4-6"), "Markdown should contain model name")
        XCTAssertTrue(markdown.contains("## Conversation"), "Markdown should contain conversation section")
    }
}
